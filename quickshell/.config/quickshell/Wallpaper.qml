import QtQuick
import Quickshell
import Quickshell.Wayland

// One wallpaper surface per screen, on the background layer.
// The image is cropped to fill; the ground colour shows while it loads.
Variants {
    model: Quickshell.screens

    PanelWindow {
        required property ShellScreen modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "horizon-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.ground

        Image {
            anchors.fill: parent
            source: Theme.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            // decode at screen size, not the photo's 4000 px
            sourceSize.width: parent.width
            sourceSize.height: parent.height
        }
    }
}
