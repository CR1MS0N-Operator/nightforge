import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

import "../../components"
import "../../services"

Item {
    id: dashboard
    property string widgetName: "dashboard"

    MatugenColors { id: mocha }

    // =========================================================
    // Data State
    // =========================================================
    property int activeTab: 0
    property var tabNames: ["Infrastructure", "Agents", "Network", "Services", "C2"]
    property var tabIcons: ["󰢱", "󱚝", "󰋙", "󰅟", "󱙝"]
    property int expandedAgent: -1
    property int expandedPeer: -1

    property var vmList: []
    property var containerList: []
    property var serviceList: []
    property var networkState: ({})
    property var c2List: []
    property var tmuxList: []

    property string containerStr: ""
    property string vmStr: ""

    property string cpuStr: "--%"
    property string ramStr: "--"
    property string uptimeStr: "--"

    property var agentSessions: []

    function agentSess(agent) {
        var r = [];
        for (var i = 0; i < agentSessions.length; i++) {
            if (agentSessions[i].agent === agent) r.push(agentSessions[i]);
        }
        return r;
    }
    function actCount(agent) {
        var c = 0;
        for (var i = 0; i < agentSessions.length; i++) {
            if (agentSessions[i].agent === agent && agentSessions[i].status === "active") c++;
        }
        return c;
    }
    function sessCount(agent) {
        var c = 0;
        for (var i = 0; i < agentSessions.length; i++) {
            if (agentSessions[i].agent === agent) c++;
        }
        return c;
    }

    // =========================================================
    // Data Processes
    // =========================================================
    Process {
        id: dashPoll
        running: true
        command: [dashCtlPath, "poll"]
        property string dashCtlPath: Quickshell.env("HOME") + "/Github/nightforge/niri-modifications/scripts/dashboard-ctl"
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    dashboard.vmList = d.vms || []
                    dashboard.containerList = d.containers || []
                    dashboard.serviceList = d.services || []
                    dashboard.networkState = d.network || {}
                    dashboard.c2List = d.c2 || []
                    dashboard.tmuxList = d.tmux || []
                    dashboard.containerStr = (d.containers || []).length + " running"
                    dashboard.vmStr = (d.vms || []).filter(function(v){ return v.status === "running" }).length + " / " + (d.vms || []).length
                } catch(e) {}
            }
        }
    }

    Process {
        id: dashAction
        running: false
        property bool dashActionOk: false
        stdout: StdioCollector {
            onStreamFinished: {
                try { var r = JSON.parse(text.trim()); dashActionOk = r.ok === true }
                catch(e) { dashActionOk = false }
            }
        }
    }

    Process {
        id: sessionPoll
        running: true
        command: [Quickshell.env("HOME") + "/Github/nightforge/session-tracker/target/release/session-tracker"]
    }
    Process {
        id: sessionRead
        running: false
        command: ["cat", "/tmp/session-tracker.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim())
                    dashboard.agentSessions = data.sessions || []
                } catch(e) { dashboard.agentSessions = [] }
            }
        }
    }

    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            dashPoll.running = false; dashPoll.running = true
            sessionPoll.running = false; sessionPoll.running = true
            sessionRead.running = true
        }
    }

    // =========================================================
    // UI
    // =========================================================
    GlassPanel {
        anchors.fill: parent
        matugen: mocha
        glassRadius: 16

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // --- Header ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "󰍝  Operator Dashboard"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    font.weight: Font.Black
                    color: mocha.text
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: refreshBtn
                    width: 28; height: 28; radius: 8
                    color: refreshMouse.containsMouse ? mocha.surface1 : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                        color: refreshMouse.containsMouse ? mocha.mauve : mocha.subtext0
                    }
                    MouseArea {
                        id: refreshMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            dashPoll.running = false; dashPoll.running = true
                            sessionPoll.running = false; sessionPoll.running = true
                            sessionRead.running = true
                        }
                    }
                }
            }

            // --- Always-visible summary bar ---
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 80
                radius: 10; color: mocha.surface1
                RowLayout {
                    anchors.fill: parent; anchors.margins: 12; spacing: 16
                    ColumnLayout { spacing: 4
                        Text { text: "󰡨 Containers"; font.pixelSize: 11; color: mocha.subtext0; font.bold: true }
                        Text { text: dashboard.containerStr; font.pixelSize: 10; color: mocha.text }
                    }
                    ColumnLayout { spacing: 4
                        Text { text: "󰻉 VMs"; font.pixelSize: 11; color: mocha.subtext0; font.bold: true }
                        Text { text: dashboard.vmStr; font.pixelSize: 10; color: mocha.text }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout { spacing: 4
                        Text { text: "󰻠 " + cpuStr; font.pixelSize: 10; color: mocha.overlay0 }
                        Text { text: " " + ramStr; font.pixelSize: 10; color: mocha.overlay0 }
                        Text { text: "󰔟 " + uptimeStr; font.pixelSize: 10; color: mocha.overlay0 }
                    }
                }
            }

            // --- Tab bar ---
            RowLayout {
                Layout.fillWidth: true; spacing: 4
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        id: tabBtn
                        height: 28; radius: 6
                        color: dashboard.activeTab === index
                            ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3)
                            : "transparent"
                        implicitWidth: tabContent.implicitWidth + 16
                        RowLayout {
                            id: tabContent; anchors.centerIn: parent; spacing: 6
                            Text { text: dashboard.tabIcons[index]; font.pixelSize: 11; color: dashboard.activeTab === index ? mocha.mauve : mocha.overlay0 }
                            Text { text: dashboard.tabNames[index]; font.pixelSize: 10; font.bold: dashboard.activeTab === index; color: dashboard.activeTab === index ? mocha.mauve : mocha.text }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: dashboard.activeTab = index
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // --- Tab content area ---
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 10; color: mocha.surface1; clip: true

                Text {
                    anchors.centerIn: parent
                    visible: dashboard.activeTab === 0
                    text: "Infrastructure (Task 3)"
                    font.pixelSize: 14; color: mocha.overlay0
                }

                Text {
                    anchors.centerIn: parent
                    visible: dashboard.activeTab === 1
                    text: "Agents (Task 4)"
                    font.pixelSize: 14; color: mocha.overlay0
                }

                Text {
                    anchors.centerIn: parent
                    visible: dashboard.activeTab === 2
                    text: "Network (Task 5)"
                    font.pixelSize: 14; color: mocha.overlay0
                }

                Text {
                    anchors.centerIn: parent
                    visible: dashboard.activeTab === 3
                    text: "Services (Task 6)"
                    font.pixelSize: 14; color: mocha.overlay0
                }

                Text {
                    anchors.centerIn: parent
                    visible: dashboard.activeTab === 4
                    text: "C2 (Task 7)"
                    font.pixelSize: 14; color: mocha.overlay0
                }
            }
        }
    }
}