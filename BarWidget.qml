// BarWidget.qml — Omazoid bar widget entry point
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

BarWidget {
    id: root
    moduleName: "com.github.LinuxGamerUK.Omazoid"

    readonly property bool opened: panelLoader.item
        ? panelLoader.item.opened === true
        : false
    readonly property bool popoutSwitchClosing: panelLoader.item
        ? panelLoader.item.popoutSwitchClosing === true
        : false

    function open() {
        if (panelLoader.item) panelLoader.item.open()
    }

    function close() {
        if (panelLoader.item) panelLoader.item.close()
    }

    function toggle() {
        if (panelLoader.item) panelLoader.item.toggle()
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
    }

    function injectPanel() {
        if (!panelLoader.item) return
        panelLoader.item.bar = root.bar
        panelLoader.item.anchorItem = button
        panelLoader.item.hostWidget = root
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    onBarChanged: injectPanel()

    // Check for save file to show status
    property bool hasSave: false
    property string saveFile: Quickshell.env("HOME") + "/.config/omarchy/plugins/com.github.LinuxGamerUK.Omazoid/saves/save.json"

    Component.onCompleted: {
        checkSaveProc.command = ["bash", "-c", "test -f '" + saveFile + "' && echo YES || echo NO"]
        checkSaveProc.running = true
    }

    Process {
        id: checkSaveProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.hasSave = String(text).indexOf("YES") >= 0
            }
        }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "🧟 Omazoid"
        tooltipText: root.hasSave ? "Continue Omazoid" : "Start Omazoid"
        onPressed: function(buttonCode) {
            if (buttonCode === Qt.LeftButton) root.toggle()
        }
    }
}