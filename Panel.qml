// Panel.qml — Omazoid bar widget panel (launch panel)
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "com.github.LinuxGamerUK.Omazoid"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property bool hasSave: false
    property string saveFile: Quickshell.env("HOME") + "/.config/omarchy/plugins/com.github.LinuxGamerUK.Omazoid/saves/save.json"

    function open() {
        root.controller.show()
        checkSaveProc.command = ["bash", "-c", "test -f '" + saveFile + "' && echo YES || echo NO"]
        checkSaveProc.running = true
    }

    function close() {
        root.controller.hide()
    }

    function switchPanel(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
            return root.bar.switchPanelFrom(root.hostWidget || root, direction)
        return false
    }

    function launchGame() {
        summonProc.command = ["omarchy-shell", "shell", "summon",
            "com.github.LinuxGamerUK.Omazoid", "{}"]
        summonProc.running = true
        root.close()
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

    Process { id: summonProc }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.hostWidget || root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(260))
        contentHeight: panel.fittedContentHeight(content.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Column {
                id: content
                width: parent.width
                spacing: Style.space(10)

                // Title
                Text {
                    width: parent.width
                    text: "🧟 OMAZOID"
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: "Zombie Survival"
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    opacity: 0.6
                    horizontalAlignment: Text.AlignHCenter
                }

                // Status
                Rectangle {
                    width: parent.width
                    height: 32
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: root.hasSave ? "Save game found" : "No save game"
                        color: root.hasSave ? "#5acf3a" : "#888888"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                    }
                }

                // Play button
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: 6
                    color: playMouse.containsMouse ? "#3a4a5a" : "#2a3a4a"
                    border.color: "#4a5a6a"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.hasSave ? "▶ Continue" : "▶ New Game"
                        color: "#ffffff"
                        font.family: root.bar ? root.bar.fontFamily : Style.font.family
                        font.pixelSize: Style.font.body
                        font.bold: true
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.launchGame()
                    }
                }

                // Controls hint
                Text {
                    width: parent.width
                    text: "WASD: Move | Mouse: Aim/Attack\nE: Loot | I: Inventory | Esc: Pause"
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.small || 11
                    opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}