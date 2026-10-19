// Glass for windows that hold many floating cards (notification banners,
// Notification Center): every visible GlassPane in the window gets KWin blur
// behind it, and with clickThrough only the panes take clicks.

#pragma once

#include <QPointer>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>

class GlassPane : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    /** Corner radius of the blurred shape. */
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    /** Extra room around the pane that still takes clicks (a close button
     *  hanging over its corner). */
    Q_PROPERTY(qreal inputMargin READ inputMargin WRITE setInputMargin NOTIFY inputMarginChanged)
    /** Off: drawn but not blurred (a pane that only takes clicks). */
    Q_PROPERTY(bool blur READ blur WRITE setBlur NOTIFY blurChanged)

public:
    explicit GlassPane(QQuickItem *parent = nullptr);
    ~GlassPane() override;

    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);
    qreal inputMargin() const { return m_inputMargin; }
    void setInputMargin(qreal margin);
    bool blur() const { return m_blur; }
    void setBlur(bool blur);

    static const QList<GlassPane *> &all();

Q_SIGNALS:
    void radiusChanged();
    void inputMarginChanged();
    void blurChanged();

private:
    qreal m_radius = 0;
    qreal m_inputMargin = 0;
    bool m_blur = true;
};

class GlassSurface : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    /** Only the panes take clicks; the rest of the window passes them on. */
    Q_PROPERTY(bool clickThrough READ clickThrough WRITE setClickThrough NOTIFY clickThroughChanged)

public:
    explicit GlassSurface(QQuickItem *parent = nullptr);

    bool clickThrough() const { return m_clickThrough; }
    void setClickThrough(bool on);

    /** Recomputes blur and input regions (done every frame anyway). */
    Q_INVOKABLE void update();

Q_SIGNALS:
    void clickThroughChanged();

protected:
    void itemChange(ItemChange change, const ItemChangeData &data) override;

private:
    QPointer<QQuickWindow> m_window;
    QMetaObject::Connection m_frameConnection;
    bool m_clickThrough = true;
    bool m_blurApplied = false;
    QRegion m_lastBlur;
    QRegion m_lastInput;
    bool m_inputApplied = false;
};
