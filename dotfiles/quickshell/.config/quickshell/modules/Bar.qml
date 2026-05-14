import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "../services"
import "../components"

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            color: "transparent"
            WlrLayershell.namespace: "nightforge-bar"

            MatugenColors { id: mocha }

            implicitHeight: 46
            exclusiveZone: 46

            // === PROPERTIES ===
            property int  volPct:  0
            property bool volMute: false
            property string battery: "N/A"
            property string kbLayout: "us"
            property string networkStatus: "Down"
            property string btStatus: "off"
            property var workspaces: []
            property int activeWsId: 1
            property string dateStr: ""

            // Media state
            property string mediaTitle: ""
            property string mediaArtist: ""
            property string mediaArt: ""
            property bool mediaPlaying: false

            // Startup animation
            property bool startupComplete: false

            Component.onCompleted: startupTimer.start()

            Timer {
                id: startupTimer
                interval: 100
                onTriggered: win.startupComplete = true
            }

            // === IPC DISPATCH ===
            function dispatch(cmd) {
                var p = Qt.createQmlObject('import Quickshell.Io; Process {}', win)
                p.command = ["sh", "-c", "echo " + cmd + " > /tmp/qs_widget_state"]
                p.running = true
            }

            // === WORKSPACE POLLING ===
            Process {
                id: wsProc
                command: ["sh", "-c", "niri msg --json workspaces | jq '[.[] | {id: .id, name: (.name // (.id | tostring)), active: .is_focused, occupied: (.active_window_id != null)}]' 2>/dev/null || echo '[]'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            var data = JSON.parse(text.trim())
                            win.activeWsId = 0
                            for (var i = 0; i < data.length; i++) {
                                if (data[i].active) win.activeWsId = data[i].id
                            }
                            win.workspaces = data
                        } catch(e) {}
                    }
                }
            }
            Timer { interval: 500; running: true; repeat: true; onTriggered: wsProc.running = true }

            // === VOLUME POLLING ===
            Process {
                id: volProc
                command: ["sh", "-c", "wpctl get-volume @DEFAULT_SINK@ 2>/dev/null || pamixer --get-volume-human 2>/dev/null"]
                running: true
                stdout: SplitParser {
                    onRead: function(data) {
                        if (!data) return
                        win.volMute = data.indexOf("MUTED") !== -1
                        var m = data.match(/([\d.]+)/)
                        if (m) win.volPct = Math.round(parseFloat(m[1]) * 100)
                    }
                }
                Component.onCompleted: running = true
            }
            Timer { interval: 1000; running: true; repeat: true; onTriggered: volProc.running = true }

            // === BATTERY POLLING ===
            Process {
                id: batProc
                command: ["sh", "-c",
                    "out=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); " +
                    "[ -n \"$out\" ] && echo \"${out}%\" || echo 'N/A'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: { var txt = text.trim(); if (txt !== "") win.battery = txt }
                }
                Component.onCompleted: running = true
            }
            Timer { interval: 60000; running: true; repeat: true; onTriggered: batProc.running = true }

            // === NETWORK POLLING ===
            Process {
                id: netProc
                command: ["sh", "-c",
                    "nmcli -t -f TYPE,STATE d 2>/dev/null | grep -q '^ethernet:connected$' && echo ETH && exit 0; " +
                    "nmcli -t -f TYPE,STATE d 2>/dev/null | grep -q '^wifi:connected$' && echo WiFi && exit 0; " +
                    "echo Down"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: { var t = text.trim(); if (t) win.networkStatus = t }
                }
                Component.onCompleted: running = true
            }
            Timer { interval: 5000; running: true; repeat: true; onTriggered: netProc.running = true }

            // === BLUETOOTH POLLING ===
            Process {
                id: btProc
                command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: { win.btStatus = text.trim() === "on" ? "on" : "off" }
                }
                Component.onCompleted: running = true
            }
            Timer { interval: 5000; running: true; repeat: true; onTriggered: btProc.running = true }

            // === KEYBOARD LAYOUT POLLING ===
            Process {
                id: kbProc
                command: ["sh", "-c", "setxkbmap -query 2>/dev/null | grep layout | awk '{print $2}' || localectl status 2>/dev/null | grep 'X11 Layout' | awk -F: '{print $2}' | xargs || echo 'us'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: { var t = text.trim(); if (t) win.kbLayout = t }
                }
                Component.onCompleted: running = true
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: kbProc.running = true }

            // === MEDIA POLLING (MPRIS) ===
            Process {
                id: mediaProc
                command: ["sh", "-c", "playerctl -s metadata --format '{{title}}\\n{{artist}}\\n{{status}}\\n{{mpris:artUrl}}' 2>/dev/null || (t=$(mpc current 2>/dev/null); [ -n \"$t\" ] && printf '%s\\n%s\\nPlaying\\n' \"$t\" \"$(mpc -f '%artist%' current 2>/dev/null)\")"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        var lines = text.trim().split('\n')
                        if (lines.length >= 3 && lines[0] !== "") {
                            win.mediaTitle = lines[0] || ""
                            win.mediaArtist = lines[1] || ""
                            win.mediaPlaying = lines[2] === "Playing"
                            win.mediaArt = lines[3] || ""
                        } else {
                            win.mediaTitle = ""
                            win.mediaArtist = ""
                            win.mediaPlaying = false
                            win.mediaArt = ""
                        }
                    }
                }
                Component.onCompleted: running = true
            }
            Timer { interval: 2000; running: true; repeat: true; onTriggered: mediaProc.running = true }

            // === CLOCK ===
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    var n = new Date()
                    var M = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                    var D = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                    win.dateStr = D[n.getDay()] + ", " + M[n.getMonth()] + " " +
                                  n.getDate().toString().padStart(2,'0')
                }
            }

            // === GLASS BACKGROUND ===
            Rectangle {
                id: barBg
                anchors.fill: parent
                anchors.topMargin: 8
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                radius: 14
                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.75)
                border.width: 1
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

                // === LEFT BUTTONS ===
                Row {
                    id: leftButtons
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    opacity: win.startupComplete ? 1 : 0
                    scale: win.startupComplete ? 1 : 0.9

                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                    BarButton {
                        icon: "\uF297"
                        
                        onClicked: win.dispatch("help")
                    }
                    BarButton {
                        icon: "\uF002"
                        
                        onClicked: win.dispatch("launcher")
                    }
                    BarButton {
                        icon: "\uF013"
                        
                        onClicked: win.dispatch("controlcenter")
                    }
                }

                // === WORKSPACE PILLS ===
                Row {
                    id: wsRow
                    anchors.left: leftButtons.right
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    opacity: win.startupComplete ? 1 : 0
                    scale: win.startupComplete ? 1 : 0.9

                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 50 } NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                    Behavior on scale { SequentialAnimation { PauseAnimation { duration: 50 } NumberAnimation { duration: 400; easing.type: Easing.OutBack } } }

                    Repeater {
                        id: wsRepeater
                        model: win.workspaces

                        delegate: Rectangle {
                            width: wsText.implicitWidth + 16
                            height: 28
                            radius: 8
                            color: modelData.active ? mocha.mauve : "transparent"

                            Behavior on color { ColorAnimation { duration: 300 } }
                            Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }

                            Text {
                                id: wsText
                                anchors.centerIn: parent
                                text: modelData.name || modelData.id
                                color: modelData.active ? mocha.base : (modelData.occupied ? mocha.text : mocha.overlay0)
                                font.pixelSize: 12
                                font.bold: modelData.active
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var p = Qt.createQmlObject('import Quickshell.Io; Process {}', win)
                                    p.command = ["niri", "msg", "action", "focus-workspace", modelData.id.toString()]
                                    p.running = true
                                }
                            }
                        }
                    }
                }

                // === INLINE MEDIA ===
                Row {
                    id: mediaRow
                    anchors.left: wsRow.right
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    visible: win.mediaTitle !== ""
                    opacity: win.startupComplete && visible ? 1 : 0
                    scale: win.startupComplete && visible ? 1 : 0.9

                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 100 } NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                    Behavior on scale { SequentialAnimation { PauseAnimation { duration: 100 } NumberAnimation { duration: 400; easing.type: Easing.OutBack } } }

                    // Album art
                    Rectangle {
                        width: 32; height: 32; radius: 6
                        color: mocha.surface0
                        Image {
                            anchors.fill: parent
                            source: win.mediaArt
                            fillMode: Image.PreserveAspectCrop
                            visible: win.mediaArt !== "" && win.mediaArt.indexOf("file://") === 0
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "\uD83C\uDFB5"
                            font.pixelSize: 14
                            visible: win.mediaArt === "" || win.mediaArt.indexOf("file://") !== 0
                        }
                    }

                    // Track info
                    Column {
                        
                        spacing: 2
                        Text {
                            text: win.mediaTitle
                            color: mocha.text
                            font.pixelSize: 11
                            font.bold: true
                            elide: Text.ElideRight
                            width: Math.min(180, implicitWidth)
                        }
                        Text {
                            text: win.mediaArtist
                            color: mocha.subtext0
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: Math.min(180, implicitWidth)
                        }
                    }

                    // Media controls
                    Row {
                        
                        spacing: 4

                        BarButton {
                            icon: "\u23EE"
                            size: 22
                            
                            onClicked: {
                                var p = Qt.createQmlObject('import Quickshell.Io; Process {}', win)
                                p.command = ["playerctl", "previous"]
                                p.running = true
                            }
                        }
                        BarButton {
                            icon: win.mediaPlaying ? "\u23F8" : "\u25B6"
                            size: 26
                            accentColor: mocha.mauve
                            
                            onClicked: {
                                var p = Qt.createQmlObject('import Quickshell.Io; Process {}', win)
                                p.command = ["playerctl", "play-pause"]
                                p.running = true
                            }
                        }
                        BarButton {
                            icon: "\u23ED"
                            size: 22
                            
                            onClicked: {
                                var p = Qt.createQmlObject('import Quickshell.Io; Process {}', win)
                                p.command = ["playerctl", "next"]
                                p.running = true
                            }
                        }
                    }

                }

                // === STATUS PILLS ===
                Row {
                    id: statusRow
                    anchors.right: dateText.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: win.startupComplete ? 1 : 0
                    scale: win.startupComplete ? 1 : 0.9

                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 150 } NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                    Behavior on scale { SequentialAnimation { PauseAnimation { duration: 150 } NumberAnimation { duration: 400; easing.type: Easing.OutBack } } }

                    StatusPill {
                        icon: "\uF1EB"
                        value: win.networkStatus
                        accentColor: win.networkStatus === "Down" ? mocha.red : mocha.green
                        
                        onClicked: win.dispatch("network")
                    }
                    StatusPill {
                        icon: "\uF294"
                        value: win.btStatus === "on" ? "On" : "Off"
                        accentColor: win.btStatus === "on" ? mocha.blue : mocha.overlay0
                        
                    }
                    StatusPill {
                        icon: win.volMute ? "\uF6A9" : "\uF028"
                        value: win.volMute ? "Mute" : (win.volPct + "%")
                        accentColor: win.volMute ? mocha.red : mocha.mauve
                        
                        onClicked: win.dispatch("music")
                    }
                    StatusPill {
                        icon: "\uF240"
                        value: win.battery
                        accentColor: mocha.text
                        
                    }
                    StatusPill {
                        icon: "\uF11C"
                        value: win.kbLayout.toUpperCase()
                        accentColor: mocha.subtext0
                        
                    }
                }

                // === DATE ===
                Text {
                    id: dateText
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.dateStr
                    color: mocha.subtext0
                    font.pixelSize: 13
                    opacity: win.startupComplete ? 1 : 0
                    scale: win.startupComplete ? 1 : 0.9

                    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: 200 } NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } }
                    Behavior on scale { SequentialAnimation { PauseAnimation { duration: 200 } NumberAnimation { duration: 400; easing.type: Easing.OutBack } } }
                }
            }
        }
    }
}
