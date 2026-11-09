import QtQuick
import Quickshell
import Quickshell.Widgets

// Horizon-styled menu for tray items (nm-applet, blueman-applet, ...).
// Replaces item.display(), which draws the menu with Qt's default widget
// style and ignores this palette. Opens upward from the tray icon; clicking
// outside closes it (popup grab). Submenus expand inline under their entry.
PopupWindow {
    id: popup

    property var handle: null          // the tray item's QsMenuHandle (item.menu)
    property real fontSize: 13

    function openAt(window, item, menuHandle) {
        handle = menuHandle;
        expanded = ({});
        maxLabel = 0;
        anchor.window = window;
        const p = item.mapToItem(null, 0, 0);
        anchor.rect.x = p.x + item.width / 2;
        anchor.rect.y = p.y - 6;
        anchor.rect.width = 1;
        anchor.rect.height = 1;
        visible = true;
    }
    function close() { visible = false }

    property var expanded: ({})        // entry → bool, for inline submenus
    property real maxLabel: 0          // widest label seen, sizes the menu

    anchor.edges: Edges.Top
    anchor.gravity: Edges.Top
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipY
    grabFocus: true
    color: "transparent"
    implicitWidth: Math.max(fontSize * 14, Math.min(fontSize * 30, maxLabel + fontSize * 5)) + 12
    implicitHeight: panel.implicitHeight

    Rectangle {
        id: panel
        width: parent.width
        implicitHeight: body.implicitHeight + 12
        radius: 8
        color: Theme.alpha(Theme.surface, 0.97)
        border.color: Theme.border
        border.width: 1

        Column {
            id: body
            x: 6
            y: 6
            width: parent.width - 12

            TrayMenuLevel { owner: popup; menu: popup.handle; depth: 0 }
        }
    }
}
