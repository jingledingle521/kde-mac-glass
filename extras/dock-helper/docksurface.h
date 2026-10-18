// The dock's own window effects: KWin blur behind the glass bar only, and an
// input region so the transparent rest of the window lets clicks through.

#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>

class DockSurface : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    /** The glass bar: blurred behind, in the shape of its mask (a KSvg
     *  FrameSvgItem's `mask`), or a rounded rect of `radius`. */
    Q_PROPERTY(QQuickItem *glass READ glass WRITE setGlass NOTIFY changed)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY changed)
    /** Takes clicks; everything else in the window passes them through. */
    Q_PROPERTY(QQuickItem *inputItem READ inputItem WRITE setInputItem NOTIFY changed)

public:
    using QObject::QObject;

    QQuickItem *glass() const { return m_glass; }
    void setGlass(QQuickItem *item);
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);
    QQuickItem *inputItem() const { return m_input; }
    void setInputItem(QQuickItem *item);

    /** Re-applies blur and input region (call when the bar moves or resizes). */
    Q_INVOKABLE void update();

Q_SIGNALS:
    void changed();

private:
    void watch(QQuickItem *item);

    QPointer<QQuickItem> m_glass;
    QPointer<QQuickItem> m_input;
    qreal m_radius = 0;
    QRegion m_lastBlur;
    QRegion m_lastInput;
};
