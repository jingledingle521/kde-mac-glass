#include "docksurface.h"

#include <KWindowEffects>

#include <QPainterPath>
#include <QQuickWindow>
#include <QTimer>

namespace
{
QRect sceneRect(QQuickItem *item)
{
    return item->mapRectToScene(QRectF(0, 0, item->width(), item->height())).toAlignedRect();
}
}

void DockSurface::watch(QQuickItem *item)
{
    if (!item) {
        return;
    }
    // Coalesced to one update per event-loop pass.
    auto queue = [this] {
        QMetaObject::invokeMethod(this, &DockSurface::update, Qt::QueuedConnection);
    };
    for (auto signal : {&QQuickItem::xChanged, &QQuickItem::yChanged, &QQuickItem::widthChanged, &QQuickItem::heightChanged}) {
        connect(item, signal, this, queue);
    }
    connect(item, &QQuickItem::windowChanged, this, queue);
    queue();
}

void DockSurface::setGlass(QQuickItem *item)
{
    if (m_glass == item) {
        return;
    }
    m_glass = item;
    watch(item);
    Q_EMIT changed();
}

void DockSurface::setRadius(qreal radius)
{
    if (m_radius == radius) {
        return;
    }
    m_radius = radius;
    update();
    Q_EMIT changed();
}

void DockSurface::setInputItem(QQuickItem *item)
{
    if (m_input == item) {
        return;
    }
    m_input = item;
    watch(item);
    Q_EMIT changed();
}

void DockSurface::update()
{
    if (m_glass && m_glass->window()) {
        QWindow *window = m_glass->window();
        const QRect rect = sceneRect(m_glass);
        // The frame's own mask when it has one (exactly the artwork's
        // corners), else a rounded rect.
        QRegion region;
        const QVariant mask = m_glass->property("mask");
        if (mask.canConvert<QRegion>() && !mask.value<QRegion>().isEmpty()) {
            region = mask.value<QRegion>().translated(rect.topLeft());
        } else {
            QPainterPath path;
            path.addRoundedRect(QRectF(rect), m_radius, m_radius);
            region = QRegion(path.toFillPolygon().toPolygon());
        }
        if (region != m_lastBlur) {
            m_lastBlur = region;
            KWindowEffects::enableBlurBehind(window, true, region);
        }
    }
    if (m_input && m_input->window()) {
        const QRegion region(sceneRect(m_input));
        if (region != m_lastInput) {
            m_lastInput = region;
            m_input->window()->setMask(region);
        }
    }
}
