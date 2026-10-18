// MacGlass widget style: Breeze for everything except menus, which are drawn
// like macOS menus. That means a rounded frosted-glass panel (KWin blurs
// behind it), items inset from the edge with a rounded blue highlight, a
// checkmark column, shortcuts as Mac symbols (⇧⌘C) and thin inset separators.
// The colours match the Menu Bar widget and the MacGlass Kvantum menus.
//
// Set it with: kwriteconfig6 --group KDE --key widgetStyle MacGlass

#include <KWindowEffects>
#include <KWindowShadow>
#include <KWindowShadowTile>

#include <QApplication>
#include <QEvent>
#include <QHash>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QPointer>
#include <QProxyStyle>
#include <QRegularExpression>
#include <QStyleFactory>
#include <QStyleOptionMenuItem>
#include <QStylePlugin>
#include <QWindow>

namespace
{
// Sizes in logical pixels.
constexpr int PanelRadius = 10;
constexpr int PanelPadding = 5; // between the panel edge and the items
constexpr int ItemRadius = 5;
constexpr int ItemPadding = 9; // inside the highlight, left and right
constexpr int ItemExtraHeight = 6; // over the font's line height
constexpr int CheckWidth = 16;
constexpr int IconGap = 6;
constexpr int ShortcutGap = 28;
constexpr int ArrowWidth = 14;
constexpr int SeparatorHeight = 11;
constexpr int ShadowSize = 22;
constexpr int ShadowOffset = 5; // the shadow falls a little lower

const QColor Highlight(49, 91, 239); // the Apple menu's hover blue

bool isDark(const QPalette &palette)
{
    return palette.color(QPalette::Window).lightnessF() < 0.5;
}

QColor withAlpha(QColor color, qreal alpha)
{
    color.setAlphaF(alpha);
    return color;
}

QColor textColor(const QPalette &palette)
{
    return isDark(palette) ? QColor(245, 245, 247) : QColor(29, 29, 31);
}

QPainterPath roundedRect(const QRectF &rect, qreal radius)
{
    QPainterPath path;
    path.addRoundedRect(rect, radius, radius);
    return path;
}

// "Ctrl+Shift+C" → "⌃⇧C", in the Mac modifier order (⌃⌥⇧⌘). Chords stay
// comma-separated.
QString macShortcut(const QString &text)
{
    static const QHash<QString, QString> keys = {
        {QStringLiteral("Ctrl"), QStringLiteral("⌃")},     {QStringLiteral("Alt"), QStringLiteral("⌥")},
        {QStringLiteral("Shift"), QStringLiteral("⇧")},    {QStringLiteral("Meta"), QStringLiteral("⌘")},
        {QStringLiteral("Return"), QStringLiteral("↩")},   {QStringLiteral("Enter"), QStringLiteral("⌤")},
        {QStringLiteral("Backspace"), QStringLiteral("⌫")}, {QStringLiteral("Del"), QStringLiteral("⌦")},
        {QStringLiteral("Delete"), QStringLiteral("⌦")},   {QStringLiteral("Esc"), QStringLiteral("⎋")},
        {QStringLiteral("Tab"), QStringLiteral("⇥")},      {QStringLiteral("Up"), QStringLiteral("↑")},
        {QStringLiteral("Down"), QStringLiteral("↓")},     {QStringLiteral("Left"), QStringLiteral("←")},
        {QStringLiteral("Right"), QStringLiteral("→")},    {QStringLiteral("PgUp"), QStringLiteral("⇞")},
        {QStringLiteral("PgDown"), QStringLiteral("⇟")},   {QStringLiteral("Home"), QStringLiteral("↖")},
        {QStringLiteral("End"), QStringLiteral("↘")},
    };
    static const QStringList order = {QStringLiteral("Ctrl"), QStringLiteral("Alt"), QStringLiteral("Shift"), QStringLiteral("Meta")};

    QStringList chords;
    for (const QString &chord : text.split(QStringLiteral(", "))) {
        QStringList parts;
        // "Ctrl++" ends in the "+" key: split on the "+"s between names only.
        QString rest = chord;
        QString key;
        while (true) {
            const int plus = rest.indexOf(QLatin1Char('+'), 1);
            if (plus < 0) {
                key = rest;
                break;
            }
            parts << rest.left(plus);
            rest = rest.mid(plus + 1);
        }
        bool known = true;
        for (const QString &part : parts) {
            known = known && order.contains(part);
        }
        if (!known) {
            chords << chord; // not a modifier combination we understand
            continue;
        }
        QString out;
        for (const QString &modifier : order) {
            if (parts.contains(modifier)) {
                out += keys.value(modifier);
            }
        }
        out += keys.value(key, key);
        chords << out;
    }
    return chords.join(QStringLiteral(", "));
}

// The soft drop shadow KWin draws around each menu, cut out under the
// rounded panel so it doesn't darken the glass.
QList<KWindowShadowTile::Ptr> shadowTiles(qreal dpr, QMargins *padding)
{
    static QHash<int, QList<KWindowShadowTile::Ptr>> cache;
    const int key = qRound(dpr * 100);
    const int s = ShadowSize;
    const int r = PanelRadius;
    const int dy = ShadowOffset;
    *padding = QMargins(s, s - dy, s, s + dy);
    if (cache.contains(key)) {
        return cache.value(key);
    }

    const int size = 2 * (s + r) + 1; // logical
    QImage image(QSize(size, size) * dpr, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::transparent);
    image.setDevicePixelRatio(dpr);
    const QRectF window(s, s - dy, 2 * r + 1, 2 * r + 1);
    {
        // Stacked rounded rects fading out make a cheap gaussian-ish blur.
        QPainter p(&image);
        p.setRenderHint(QPainter::Antialiasing);
        p.setPen(Qt::NoPen);
        for (int i = s; i > 0; --i) {
            // Each ring adds a little: darkest at the panel, fading outwards.
            p.setBrush(QColor(0, 0, 0, 6));
            p.drawPath(roundedRect(window.translated(0, dy).adjusted(-i, -i, i, i), r + i));
        }
        // Then fade the whole thing: macOS menu shadows are faint.
        p.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        p.fillRect(QRectF(0, 0, size, size), QColor(0, 0, 0, 26));
        p.setCompositionMode(QPainter::CompositionMode_Clear);
        p.setBrush(Qt::black);
        p.drawPath(roundedRect(window, r));
    }

    // Nine tiles around the window's one-pixel middle.
    const int top = s - dy + r, left = s + r;
    auto tile = [&](int x, int y, int w, int h) {
        QImage piece = image.copy(QRect(x * dpr, y * dpr, w * dpr, h * dpr));
        piece.setDevicePixelRatio(dpr);
        auto t = KWindowShadowTile::Ptr::create();
        t->setImage(piece);
        t->create();
        return t;
    };
    const int bottomH = size - top - 1;
    const int rightW = size - left - 1;
    QList<KWindowShadowTile::Ptr> tiles = {
        tile(0, 0, left, top), // top left
        tile(left, 0, 1, top), // top
        tile(left + 1, 0, rightW, top), // top right
        tile(left + 1, top, rightW, 1), // right
        tile(left + 1, top + 1, rightW, bottomH), // bottom right
        tile(left, top + 1, 1, bottomH), // bottom
        tile(0, top + 1, left, bottomH), // bottom left
        tile(0, top, left, 1), // left
    };
    cache.insert(key, tiles);
    return tiles;
}

// Gives each menu window its blur and shadow as it's shown and resized.
class MenuDecorator : public QObject
{
public:
    using QObject::QObject;

    bool eventFilter(QObject *object, QEvent *event) override
    {
        auto *menu = qobject_cast<QMenu *>(object);
        if (!menu) {
            return false;
        }
        switch (event->type()) {
        case QEvent::Show:
        case QEvent::Resize:
            decorate(menu);
            break;
        case QEvent::Hide:
            if (auto *shadow = m_shadows.take(menu)) {
                shadow->destroy();
                delete shadow;
            }
            break;
        default:
            break;
        }
        return false;
    }

private:
    void decorate(QMenu *menu)
    {
        QWindow *window = menu->windowHandle();
        if (!window) {
            return;
        }
        const QRect rect = menu->rect();
        KWindowEffects::enableBlurBehind(window, true, QRegion(roundedRect(rect, PanelRadius).toFillPolygon().toPolygon()));

        KWindowShadow *shadow = m_shadows.value(menu);
        if (!shadow) {
            shadow = new KWindowShadow(menu);
            m_shadows.insert(menu, shadow);
        } else if (shadow->isCreated()) {
            return; // tiles don't depend on the size
        }
        QMargins padding;
        // The tiles are drawn at their pixel size and the padding is in
        // device pixels too: logical padding pulled the shadow in under the
        // glass on a scaled screen.
        const qreal dpr = window->devicePixelRatio();
        const auto tiles = shadowTiles(dpr, &padding);
        padding = QMargins(qRound(padding.left() * dpr), qRound(padding.top() * dpr), qRound(padding.right() * dpr), qRound(padding.bottom() * dpr));
        shadow->setTopLeftTile(tiles[0]);
        shadow->setTopTile(tiles[1]);
        shadow->setTopRightTile(tiles[2]);
        shadow->setRightTile(tiles[3]);
        shadow->setBottomRightTile(tiles[4]);
        shadow->setBottomTile(tiles[5]);
        shadow->setBottomLeftTile(tiles[6]);
        shadow->setLeftTile(tiles[7]);
        shadow->setPadding(padding);
        shadow->setWindow(window);
        shadow->create();
    }

    QHash<QMenu *, KWindowShadow *> m_shadows;
};

class MacGlassStyle : public QProxyStyle
{
public:
    MacGlassStyle()
        : QProxyStyle(QStyleFactory::create(QStringLiteral("breeze")))
        , m_decorator(new MenuDecorator(this))
    {
    }

    void polish(QWidget *widget) override
    {
        if (auto *menu = qobject_cast<QMenu *>(widget)) {
            // Not Breeze's menu setup: its shadow and blur are for its own
            // (smaller) corners.
            QCommonStyle::polish(widget);
            menu->setAttribute(Qt::WA_TranslucentBackground);
            menu->installEventFilter(m_decorator);
            return;
        }
        QProxyStyle::polish(widget);
    }

    void unpolish(QWidget *widget) override
    {
        if (qobject_cast<QMenu *>(widget)) {
            widget->removeEventFilter(m_decorator);
            QCommonStyle::unpolish(widget);
            return;
        }
        QProxyStyle::unpolish(widget);
    }

    using QProxyStyle::polish;
    using QProxyStyle::unpolish;

    int pixelMetric(PixelMetric metric, const QStyleOption *option, const QWidget *widget) const override
    {
        switch (metric) {
        case PM_MenuPanelWidth:
            return 0;
        case PM_MenuHMargin:
        case PM_MenuVMargin:
            return PanelPadding;
        case PM_SubMenuOverlap:
            return -PanelPadding; // the submenu's first item lines up with its parent
        default:
            return QProxyStyle::pixelMetric(metric, option, widget);
        }
    }

    int styleHint(StyleHint hint, const QStyleOption *option, const QWidget *widget, QStyleHintReturn *returnData) const override
    {
        switch (hint) {
        case SH_Menu_Mask:
            return 0;
        case SH_Menu_SubMenuPopupDelay:
            return 150;
        case SH_Menu_FadeOutOnHide:
            return 0;
        default:
            return QProxyStyle::styleHint(hint, option, widget, returnData);
        }
    }

    QSize sizeFromContents(ContentsType type, const QStyleOption *option, const QSize &size, const QWidget *widget) const override
    {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (type != CT_MenuItem || !item) {
            return QProxyStyle::sizeFromContents(type, option, size, widget);
        }
        const QFontMetrics fm(item->font);
        if (item->menuItemType == QStyleOptionMenuItem::Separator) {
            if (item->text.isEmpty()) {
                return QSize(size.width(), SeparatorHeight);
            }
            QFont font = item->font;
            font.setWeight(QFont::DemiBold);
            const QFontMetrics hfm(font);
            return QSize(hfm.horizontalAdvance(item->text) + 2 * ItemPadding, hfm.height() + 6);
        }
        // QMenu only learns that it has checkable items while it's measuring
        // them, so the rows before the first one are asked for without the
        // checkmark column: always count it, or longer labels get cut off.
        // (+4: QMenu measures with integer bounding rects, and the widest label
        // came out a pixel or two short and got elided.)
        int width = ItemPadding + CheckWidth + size.width() + ArrowWidth + ItemPadding + 4;
        if (item->maxIconWidth > 0 || !item->icon.isNull()) {
            width += 16 + IconGap;
        }
        if (item->text.contains(QLatin1Char('\t'))) {
            width += ShortcutGap;
        }
        const int iconHeight = item->maxIconWidth > 0 ? 16 : 0;
        return QSize(width, qMax(fm.height(), iconHeight) + ItemExtraHeight);
    }

    void drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const override
    {
        if (element == PE_FrameMenu) {
            return; // drawn with the panel
        }
        if (element != PE_PanelMenu) {
            QProxyStyle::drawPrimitive(element, option, painter, widget);
            return;
        }
        const bool dark = isDark(option->palette);
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        const QRectF rect = QRectF(option->rect).adjusted(0.5, 0.5, -0.5, -0.5);
        // Translucent glass (KWin blurs behind it), a dark outline and a light
        // inner rim, like the dock and the Menu Bar widget's menus.
        painter->setPen(QPen(dark ? QColor(0, 0, 0, 115) : QColor(0, 0, 0, 40), 1));
        painter->setBrush(dark ? QColor(42, 44, 48, 180) : QColor(246, 246, 248, 190));
        painter->drawPath(roundedRect(rect, PanelRadius));
        painter->setPen(QPen(dark ? QColor(255, 255, 255, 26) : QColor(255, 255, 255, 110), 1));
        painter->setBrush(Qt::NoBrush);
        painter->drawPath(roundedRect(rect.adjusted(1, 1, -1, -1), PanelRadius - 1));
        painter->restore();
    }

    void drawControl(ControlElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const override
    {
        const auto *item = qstyleoption_cast<const QStyleOptionMenuItem *>(option);
        if (element != CE_MenuItem || !item) {
            if (element == CE_MenuEmptyArea || element == CE_MenuTearoff) {
                return;
            }
            QProxyStyle::drawControl(element, option, painter, widget);
            return;
        }
        painter->save();
        painter->setRenderHint(QPainter::Antialiasing);
        drawMenuItem(item, painter);
        painter->restore();
    }

private:
    void drawMenuItem(const QStyleOptionMenuItem *item, QPainter *painter) const
    {
        const QPalette &palette = item->palette;
        const bool dark = isDark(palette);
        const QRect rect = item->rect;

        if (item->menuItemType == QStyleOptionMenuItem::Separator) {
            if (item->text.isEmpty()) {
                const int y = rect.center().y();
                painter->setRenderHint(QPainter::Antialiasing, false);
                painter->fillRect(QRect(rect.left() + ItemPadding, y, rect.width() - 2 * ItemPadding, 1),
                                  dark ? QColor(255, 255, 255, 38) : QColor(0, 0, 0, 30));
                return;
            }
            // A section heading: small, bold and dimmed.
            QFont font = item->font;
            font.setWeight(QFont::DemiBold);
            painter->setFont(font);
            painter->setPen(withAlpha(textColor(palette), 0.5));
            painter->drawText(rect.adjusted(ItemPadding, 0, -ItemPadding, 0), Qt::AlignVCenter | Qt::AlignLeft | Qt::TextHideMnemonic, item->text);
            return;
        }

        const bool enabled = item->state & State_Enabled;
        const bool selected = enabled && (item->state & State_Selected);
        if (selected) {
            painter->setPen(Qt::NoPen);
            painter->setBrush(Highlight);
            painter->drawPath(roundedRect(QRectF(rect), ItemRadius));
        }

        QColor fg = selected ? QColor(Qt::white) : textColor(palette);
        if (!enabled) {
            fg = withAlpha(fg, 0.3);
        }
        const QColor secondary = selected ? withAlpha(Qt::white, 0.85) : withAlpha(fg, enabled ? 0.5 : 0.3);

        int x = rect.left() + ItemPadding;
        const int cy = rect.center().y();

        if (item->menuHasCheckableItems) {
            if (item->checked) {
                QPen pen(fg, 1.6);
                pen.setCapStyle(Qt::RoundCap);
                pen.setJoinStyle(Qt::RoundJoin);
                painter->setPen(pen);
                painter->setBrush(Qt::NoBrush);
                if (item->checkType == QStyleOptionMenuItem::Exclusive) {
                    // Radio items get the same tick on macOS; keep a dot for
                    // apps that rely on it to read as a choice.
                    painter->setPen(Qt::NoPen);
                    painter->setBrush(fg);
                    painter->drawEllipse(QPointF(x + 4.5, cy + 0.5), 3, 3);
                } else {
                    QPainterPath tick;
                    tick.moveTo(x + 0.5, cy + 0.5);
                    tick.lineTo(x + 3.5, cy + 3.5);
                    tick.lineTo(x + 9.5, cy - 3.5);
                    painter->drawPath(tick);
                }
            }
            x += CheckWidth;
        }

        if (item->maxIconWidth > 0) {
            if (!item->icon.isNull()) {
                const QIcon::Mode mode = !enabled ? QIcon::Disabled : selected ? QIcon::Selected : QIcon::Normal;
                const QPixmap pixmap = item->icon.pixmap(QSize(16, 16), painter->device()->devicePixelRatioF(), mode, QIcon::Off);
                painter->drawPixmap(QRect(x, cy - 8, 16, 16), pixmap);
            }
            x += 16 + IconGap;
        }

        const int right = rect.right() - ItemPadding;
        QString text = item->text;
        QString shortcut;
        const int tab = text.indexOf(QLatin1Char('\t'));
        if (tab >= 0) {
            shortcut = macShortcut(text.mid(tab + 1));
            text = text.left(tab);
        }

        // Measured and elided without the mnemonic marker ("Show &Previews",
        // added by KDE's accelerator manager): counting the "&" cut labels short.
        text.replace(QRegularExpression(QStringLiteral("&(.)")), QStringLiteral("\\1"));

        painter->setFont(item->font);
        const QRect textRect(x, rect.top(), right - ArrowWidth - x, rect.height());
        painter->setPen(fg);
        painter->drawText(textRect, Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine,
                          QFontMetrics(item->font).elidedText(text, Qt::ElideRight, textRect.width()));

        if (!shortcut.isEmpty()) {
            painter->setPen(secondary);
            painter->drawText(QRect(x, rect.top(), right - ArrowWidth / 2 - x, rect.height()), Qt::AlignVCenter | Qt::AlignRight | Qt::TextSingleLine,
                              shortcut);
        }

        if (item->menuItemType == QStyleOptionMenuItem::SubMenu) {
            // A small chevron, like macOS.
            QPen pen(selected ? fg : secondary, 1.5);
            pen.setCapStyle(Qt::RoundCap);
            pen.setJoinStyle(Qt::RoundJoin);
            painter->setPen(pen);
            painter->setBrush(Qt::NoBrush);
            const qreal ax = right - 4.5;
            QPainterPath chevron;
            chevron.moveTo(ax - 3, cy - 4.5);
            chevron.lineTo(ax + 1, cy + 0.5);
            chevron.lineTo(ax - 3, cy + 5.5);
            painter->drawPath(chevron);
        }
    }

    MenuDecorator *m_decorator;
};

} // namespace

class MacGlassStylePlugin : public QStylePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QStyleFactoryInterface_iid FILE "macglass.json")

public:
    QStyle *create(const QString &key) override
    {
        if (key.compare(QLatin1String("macglass"), Qt::CaseInsensitive) == 0) {
            return new MacGlassStyle;
        }
        return nullptr;
    }
};

#include "macglassstyle.moc"
