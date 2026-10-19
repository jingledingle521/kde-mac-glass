#include "glasssurface.h"

#include <KWindowEffects>

#include <QPainterPath>

namespace
{
QList<GlassPane *> s_panes;

// The pane's on-screen rect, cut to every clipping item above it (a pane
// scrolled out of a list isn't blurred).
QRectF visibleRect(QQuickItem *item, QRectF rect)
{
    rect = item->mapRectToScene(rect);
    for (QQuickItem *p = item->parentItem(); p; p = p->parentItem()) {
        if (p->clip()) {
            rect &= p->mapRectToScene(QRectF(0, 0, p->width(), p->height()));
        }
    }
    return rect;
}

bool showing(QQuickItem *item)
{
    if (!item->isVisible() || item->width() <= 0 || item->height() <= 0) {
        return false;
    }
    qreal opacity = 1;
    for (QQuickItem *p = item; p; p = p->parentItem()) {
        opacity *= p->opacity();
    }
    return opacity > 0.02;
}

QRegion rounded(const QRectF &rect, qreal radius)
{
    QPainterPath path;
    path.addRoundedRect(rect, radius, radius);
    return QRegion(path.toFillPolygon().toPolygon());
}
}

GlassPane::GlassPane(QQuickItem *parent)
    : QQuickItem(parent)
{
    s_panes.append(this);
}

GlassPane::~GlassPane()
{
    s_panes.removeOne(this);
}

const QList<GlassPane *> &GlassPane::all()
{
    return s_panes;
}

void GlassPane::setRadius(qreal radius)
{
    if (m_radius != radius) {
        m_radius = radius;
        Q_EMIT radiusChanged();
    }
}

void GlassPane::setInputMargin(qreal margin)
{
    if (m_inputMargin != margin) {
        m_inputMargin = margin;
        Q_EMIT inputMarginChanged();
    }
}

void GlassPane::setBlur(bool blur)
{
    if (m_blur != blur) {
        m_blur = blur;
        Q_EMIT blurChanged();
    }
}

GlassSurface::GlassSurface(QQuickItem *parent)
    : QQuickItem(parent)
{
}

void GlassSurface::setClickThrough(bool on)
{
    if (m_clickThrough != on) {
        m_clickThrough = on;
        update();
        Q_EMIT clickThroughChanged();
    }
}

void GlassSurface::itemChange(ItemChange change, const ItemChangeData &data)
{
    if (change == ItemSceneChange) {
        disconnect(m_frameConnection);
        m_window = data.window;
        m_blurApplied = false;
        m_inputApplied = false;
        m_lastBlur = {};
        m_lastInput = {};
        if (m_window) {
            // Panes move with animations and scrolling, which don't tell their
            // children: check once per frame, before it's drawn.
            m_frameConnection = connect(m_window, &QQuickWindow::afterAnimating, this, &GlassSurface::update);
            QMetaObject::invokeMethod(this, &GlassSurface::update, Qt::QueuedConnection);
        }
    }
    QQuickItem::itemChange(change, data);
}

void GlassSurface::update()
{
    if (!m_window) {
        return;
    }
    QRegion blur;
    QRegion input;
    for (GlassPane *pane : GlassPane::all()) {
        if (pane->window() != m_window || !showing(pane)) {
            continue;
        }
        const QRectF local(0, 0, pane->width(), pane->height());
        const QRectF rect = visibleRect(pane, local);
        if (rect.isEmpty()) {
            continue;
        }
        // Scaled panes (a stack's lower cards) scale their corners too.
        const qreal scale = pane->mapRectToScene(local).width() / pane->width();
        if (pane->blur()) {
            // A pixel inside the edge: the region is whole logical pixels,
            // scaled by the compositor, and blur reaching past the pane's
            // antialiased edge shows as a bright rim around it.
            const qreal inset = 1;
            blur += rounded(rect.adjusted(inset, inset, -inset, -inset), qMax<qreal>(0, pane->radius() * scale - inset));
        }
        const qreal m = pane->inputMargin();
        input += visibleRect(pane, local.adjusted(-m, -m, m, m)).toAlignedRect();
    }

    if (!m_blurApplied || blur != m_lastBlur) {
        m_blurApplied = true;
        m_lastBlur = blur;
        KWindowEffects::enableBlurBehind(m_window, !blur.isEmpty(), blur);
    }

    // An empty mask means "the whole window" to Qt, so with no panes keep
    // a single pixel.
    if (!m_clickThrough) {
        input = {};
    } else if (input.isEmpty()) {
        input = QRegion(0, 0, 1, 1);
    }
    if (!m_inputApplied || input != m_lastInput) {
        m_inputApplied = true;
        m_lastInput = input;
        m_window->setMask(input);
    }
}
