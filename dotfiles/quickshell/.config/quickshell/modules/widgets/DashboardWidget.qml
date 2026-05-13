import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
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

Flickable {
    anchors.fill: parent; anchors.margins: 8
    contentWidth: infraCol.width; contentHeight: infraCol.height
    clip: true; visible: dashboard.activeTab === 0

    ColumnLayout {
        id: infraCol; width: parent.width; spacing: 12

        // --- Virtual Machines ---
        Rectangle {
            Layout.fillWidth: true; implicitHeight: vmSection.implicitHeight + 20
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: vmSection
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 8
                Text {
                    text: "󰻉  Virtual Machines"
                    font.pixelSize: 12; font.bold: true; color: mocha.subtext0
                }
                Repeater {
                    model: dashboard.vmList
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 6
                        color: mocha.base
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4
                                color: modelData.status === "running" ? mocha.green : mocha.overlay0 }
                            Text { text: modelData.name; font.pixelSize: 11; font.bold: true; color: mocha.text }
                            Text { text: modelData.vcpus + " vCPU  ·  " + modelData.memory + " MB"
                                font.pixelSize: 9; color: mocha.overlay0 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 24; radius: 4; implicitWidth: btnText.implicitWidth + 16
                                color: modelData.status === "running" ? mocha.red : mocha.green
                                opacity: 0.2
                                Text { id: btnText; anchors.centerIn: parent
                                    text: modelData.status === "running" ? "Stop" : "Start"
                                    font.pixelSize: 9; color: modelData.status === "running" ? mocha.red : mocha.green }
                                MouseArea { anchors.fill: parent
                                    onClicked: {
                                        dashAction.command = [dashPoll.dashCtlPath, "vm",
                                            modelData.status === "running" ? "stop" : "start", modelData.name]
                                        dashAction.running = false; dashAction.running = true
                                    }
                                }
                            }
                        }
                    }
                }
                Text { text: "No VMs configured"; font.pixelSize: 10; color: mocha.overlay0
                    visible: dashboard.vmList.length === 0 }
            }
        }

        // --- Containers ---
        Rectangle {
            Layout.fillWidth: true; implicitHeight: ctSection.implicitHeight + 20
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: ctSection
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 8
                Text {
                    text: "󰡨  Containers"
                    font.pixelSize: 12; font.bold: true; color: mocha.subtext0
                }
                Repeater {
                    model: dashboard.containerList
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 6
                        color: mocha.base
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4
                                color: modelData.status === "running" ? mocha.green : mocha.overlay0 }
                            Text { text: modelData.name; font.pixelSize: 11; font.bold: true; color: mocha.text }
                            Text { text: modelData.image + (modelData.ports ? "  ·  " + modelData.ports : "")
                                font.pixelSize: 9; color: mocha.overlay0 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 24; radius: 4; implicitWidth: ctBtnText.implicitWidth + 16
                                color: modelData.status === "running" ? mocha.red : mocha.green
                                opacity: 0.2
                                Text { id: ctBtnText; anchors.centerIn: parent
                                    text: modelData.status === "running" ? "Stop" : "Start"
                                    font.pixelSize: 9; color: modelData.status === "running" ? mocha.red : mocha.green }
                                MouseArea { anchors.fill: parent
                                    onClicked: {
                                        dashAction.command = [dashPoll.dashCtlPath, "container",
                                            modelData.status === "running" ? "stop" : "start", modelData.name]
                                        dashAction.running = false; dashAction.running = true
                                    }
                                }
                            }
                        }
                    }
                }
                Text { text: "No containers running"; font.pixelSize: 10; color: mocha.overlay0
                    visible: dashboard.containerList.length === 0 }
            }
        }
    }
}

Flickable {
    anchors.fill: parent; anchors.margins: 8
    contentWidth: agentsCol.width; contentHeight: agentsCol.height
    clip: true; visible: dashboard.activeTab === 1

    ColumnLayout {
        id: agentsCol; width: parent.width; spacing: 12

        // --- OpenCode Card ---
        Rectangle {
            Layout.fillWidth: true; implicitHeight: ocCard.implicitHeight + 16
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: ocCard
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 6

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4
                        color: dashboard.actCount("opencode") > 0 ? mocha.green : mocha.overlay0 }
                    Text { text: "󰨞 OpenCode"; font.pixelSize: 12; font.bold: true; color: mocha.text }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        height: 26; radius: 4; implicitWidth: 60; color: mocha.mauve; opacity: 0.2
                        Text { anchors.centerIn: parent; text: "New"; font.pixelSize: 9; color: mocha.mauve }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached("ghostty", ["-e", "opencode"])
                                    || Quickshell.execDetached("kitty", ["opencode"])
                                    || Quickshell.execDetached("alacritty", ["-e", "opencode"])
                                    || Quickshell.execDetached("xterm", ["-e", "opencode"])
                            }
                        }
                    }
                    Rectangle {
                        height: 26; radius: 4; implicitWidth: 70; color: mocha.teal; opacity: 0.15
                        Text { anchors.centerIn: parent; text: "Resume"; font.pixelSize: 9; color: mocha.teal }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: dashboard.ocResumePopup.visible = true
                        }
                    }
                }
                Text { text: "⚡ " + (dashboard.agentSess("opencode").length > 0 ? (dashboard.agentSess("opencode")[0].machine || "local") : "local") + "  ·  📁 " + (dashboard.agentSess("opencode").length > 0 ? (dashboard.agentSess("opencode")[0].workdir || "—") : "—")
                    font.pixelSize: 9; color: mocha.overlay0 }

                ListView {
                    Layout.fillWidth: true
                    height: dashboard.expandedAgent === 0 ? Math.min(dashboard.agentSess("opencode").length * 36, 160) : 0
                    visible: dashboard.expandedAgent === 0
                    clip: true; spacing: 3
                    model: {
                        var r = []
                        for (var i = 0; i < dashboard.agentSessions.length; i++) {
                            if (dashboard.agentSessions[i].agent === "opencode") r.push(dashboard.agentSessions[i])
                        }
                        return r
                    }
                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 34; radius: 6
                        color: mocha.base
                        clip: true
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 6
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: modelData.status === "active" ? mocha.green : mocha.overlay0
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.id.replace("stats-pid-","").replace("session_","").substring(0, 12)
                                    font.pixelSize: 10; font.bold: true; color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.model + "  ·  " + modelData.total_calls + "c  ·  " +
                                          Math.round(modelData.uptime_seconds/60) + "m"
                                    font.pixelSize: 8; color: mocha.overlay0
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                text: {
                                    if (modelData.cost_saved > 0.01) return "$" + modelData.cost_saved.toFixed(2)
                                    if (modelData.tokens_saved > 0) return (modelData.tokens_saved/1000).toFixed(1) + "k tok"
                                    return ""
                                }
                                font.pixelSize: 9; color: mocha.teal
                                visible: modelData.tokens_saved > 0 || modelData.cost_saved > 0.01
                            }
                        }
                    }
                }
            }
            MouseArea { anchors.fill: parent
                onClicked: dashboard.expandedAgent = (dashboard.expandedAgent === 0 ? -1 : 0) }
        }

        // --- Hermes Card ---
        Rectangle {
            Layout.fillWidth: true; implicitHeight: hermesCard.implicitHeight + 16
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: hermesCard
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 6

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4
                        color: dashboard.actCount("hermes") > 0 ? mocha.green : mocha.overlay0 }
                    Text { text: "󰣇 Hermes"; font.pixelSize: 12; font.bold: true; color: mocha.text }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        height: 26; radius: 4; implicitWidth: 60; color: mocha.mauve; opacity: 0.2
                        Text { anchors.centerIn: parent; text: "New"; font.pixelSize: 9; color: mocha.mauve }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached("ghostty", ["-e", "hermes"])
                                    || Quickshell.execDetached("kitty", ["hermes"])
                                    || Quickshell.execDetached("alacritty", ["-e", "hermes"])
                                    || Quickshell.execDetached("xterm", ["-e", "hermes"])
                            }
                        }
                    }
                }
                Text { text: "⚡ " + (dashboard.agentSess("hermes").length > 0 ? (dashboard.agentSess("hermes")[0].machine || "local") : "local") + "  ·  📁 " + (dashboard.agentSess("hermes").length > 0 ? (dashboard.agentSess("hermes")[0].workdir || "—") : "—")
                    font.pixelSize: 9; color: mocha.overlay0 }

                ListView {
                    Layout.fillWidth: true
                    height: dashboard.expandedAgent === 1 ? Math.min(dashboard.agentSess("hermes").length * 36, 160) : 0
                    visible: dashboard.expandedAgent === 1
                    clip: true; spacing: 3
                    model: {
                        var r = []
                        for (var i = 0; i < dashboard.agentSessions.length; i++) {
                            if (dashboard.agentSessions[i].agent === "hermes") r.push(dashboard.agentSessions[i])
                        }
                        return r
                    }
                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: 34; radius: 6
                        color: mocha.base
                        clip: true
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 6
                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: modelData.status === "active" ? mocha.green : mocha.overlay0
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.id.replace("stats-pid-","").replace("session_","").substring(0, 12)
                                    font.pixelSize: 10; font.bold: true; color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.model + "  ·  " + modelData.total_calls + "c  ·  " +
                                          Math.round(modelData.uptime_seconds/60) + "m"
                                    font.pixelSize: 8; color: mocha.overlay0
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                text: {
                                    if (modelData.cost_saved > 0.01) return "$" + modelData.cost_saved.toFixed(2)
                                    if (modelData.tokens_saved > 0) return (modelData.tokens_saved/1000).toFixed(1) + "k tok"
                                    return ""
                                }
                                font.pixelSize: 9; color: mocha.teal
                                visible: modelData.tokens_saved > 0 || modelData.cost_saved > 0.01
                            }
                        }
                    }
                }
            }
            MouseArea { anchors.fill: parent
                onClicked: dashboard.expandedAgent = (dashboard.expandedAgent === 1 ? -1 : 1) }
        }

        // --- Tmux Sessions ---
        Rectangle {
            Layout.fillWidth: true; implicitHeight: tmuxSection.implicitHeight + 20
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: tmuxSection
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 6
                Text { text: "  Tmux Sessions"; font.pixelSize: 12; font.bold: true; color: mocha.subtext0 }
                Repeater {
                    model: dashboard.tmuxList
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 6; color: mocha.base
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4
                                color: modelData.attached ? mocha.green : mocha.overlay0 }
                            Text { text: modelData.session; font.pixelSize: 11; font.bold: true; color: mocha.text }
                            Text { text: modelData.windows + " windows"; font.pixelSize: 9; color: mocha.overlay0 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 24; radius: 4; implicitWidth: 60; color: mocha.mauve; opacity: 0.15
                                Text { anchors.centerIn: parent; text: "Attach"; font.pixelSize: 9; color: mocha.mauve }
                                MouseArea { anchors.fill: parent
                                    onClicked: {
                                        Quickshell.execDetached("ghostty", ["-e", "tmux", "attach", "-t", modelData.session])
                                            || Quickshell.execDetached("kitty", ["sh", "-c", "tmux attach -t " + modelData.session])
                                            || Quickshell.execDetached("alacritty", ["-e", "tmux", "attach", "-t", modelData.session])
                                    }
                                }
                            }
                        }
                    }
                }
                Text { text: "No tmux sessions"; font.pixelSize: 10; color: mocha.overlay0
                    visible: dashboard.tmuxList.length === 0 }
            }
        }
    }
}

Flickable {
    anchors.fill: parent; anchors.margins: 8
    contentWidth: netCol.width; contentHeight: netCol.height
    clip: true; visible: dashboard.activeTab === 2

    ColumnLayout {
        id: netCol; width: parent.width; spacing: 12

        // WireGuard
        Rectangle {
            Layout.fillWidth: true; implicitHeight: wgSection.implicitHeight + 20
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: wgSection
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 6
                Text { text: "󰒘  WireGuard"; font.pixelSize: 12; font.bold: true; color: mocha.subtext0 }
                Repeater {
                    model: dashboard.networkState.wg || []
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 40; radius: 6; color: mocha.base
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4
                                color: modelData.status === "up" ? mocha.green : mocha.overlay0 }
                            Text { text: modelData.name; font.pixelSize: 11; font.bold: true; color: mocha.text }
                            Text { text: modelData.ip || ""; font.pixelSize: 9; color: mocha.overlay0 }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                height: 24; radius: 4; implicitWidth: btnTunnelText.implicitWidth + 16
                                color: modelData.status === "up" ? mocha.red : mocha.green; opacity: 0.2
                                Text { id: btnTunnelText; anchors.centerIn: parent
                                    text: modelData.status === "up" ? "Down" : "Up"
                                    font.pixelSize: 9; color: modelData.status === "up" ? mocha.red : mocha.green }
                                MouseArea { anchors.fill: parent
                                    onClicked: {
                                        dashAction.command = [dashPoll.dashCtlPath, "network", "wg",
                                            modelData.status === "up" ? "down" : "up", modelData.name]
                                        dashAction.running = false; dashAction.running = true
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // nftables
        Rectangle {
            Layout.fillWidth: true; height: 40; radius: 6; color: mocha.surface0
            RowLayout {
                anchors.fill: parent; anchors.margins: 8; spacing: 8
                Text { text: "󰯱  Firewall (nftables)"; font.pixelSize: 11; font.bold: true; color: mocha.subtext0 }
                Text { text: ((dashboard.networkState.nftables || {}).rules_count || 0) + " rules"
                    font.pixelSize: 9; color: mocha.overlay0 }
                Item { Layout.fillWidth: true }
                Rectangle {
                    height: 24; radius: 4; implicitWidth: nftBtnText.implicitWidth + 16
                    color: (dashboard.networkState.nftables || {}).enabled ? mocha.red : mocha.green; opacity: 0.2
                    Text { id: nftBtnText; anchors.centerIn: parent
                        text: (dashboard.networkState.nftables || {}).enabled ? "Disable" : "Enable"
                        font.pixelSize: 9; color: (dashboard.networkState.nftables || {}).enabled ? mocha.red : mocha.green }
                    MouseArea { anchors.fill: parent
                        onClicked: {
                            dashAction.command = [dashPoll.dashCtlPath, "network", "nftables",
                                (dashboard.networkState.nftables || {}).enabled ? "disable" : "enable"]
                            dashAction.running = false; dashAction.running = true
                        }
                    }
                }
            }
        }

        // Wifi + Ethernet + DNS
        Rectangle {
            Layout.fillWidth: true; implicitHeight: connSection.implicitHeight + 20
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: connSection
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 4
                Text { text: "󰖩  Connections"; font.pixelSize: 12; font.bold: true; color: mocha.subtext0 }
                Text { text: "WiFi: " + ((dashboard.networkState.wifi || {}).ssid || "Disconnected")
                    + (((dashboard.networkState.wifi || {}).connected) ? " (" + (dashboard.networkState.wifi || {}).strength + "%)" : "")
                    font.pixelSize: 10; color: mocha.text }
                Text { text: "Ethernet: " + ((dashboard.networkState.ethernet || {}).up ? ((dashboard.networkState.ethernet || {}).ip || "connected") : "Disconnected")
                    font.pixelSize: 10; color: mocha.text }
                Text { text: "DNS: " + ((dashboard.networkState || {}).dns || "system default")
                    font.pixelSize: 10; color: mocha.overlay0 }
            }
        }

        // WireGuard Peers
        Rectangle {
            Layout.fillWidth: true; implicitHeight: peersSection.implicitHeight + 20
            radius: 8; color: mocha.surface0
            ColumnLayout {
                id: peersSection
                anchors.left: parent.left; anchors.right: parent.right
                anchors.top: parent.top; anchors.margins: 12; spacing: 4
                Text { text: "󰤨  Peers"; font.pixelSize: 12; font.bold: true; color: mocha.subtext0 }
                Repeater {
                    model: { var peers = []; for (var i = 0; i < (dashboard.networkState.wg || []).length; i++) { for (var j = 0; j < (dashboard.networkState.wg[i].peers || []).length; j++) { peers.push(dashboard.networkState.wg[i].peers[j]) } } return peers; }
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 28; radius: 4; color: mocha.base
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 6; spacing: 6
                            Rectangle { width: 6; height: 6; radius: 3
                                color: modelData.connected ? mocha.green : mocha.overlay0 }
                            Text { text: modelData.name; font.pixelSize: 10; color: mocha.text }
                            Item { Layout.fillWidth: true }
                            Text { text: modelData.latest_handshake || ""; font.pixelSize: 8; color: mocha.overlay0 }
                        }
                    }
                }
            }
        }
    }
}

Flickable {
    anchors.fill: parent; anchors.margins: 8
    contentWidth: svcsCol.width; contentHeight: svcsCol.height
    clip: true; visible: dashboard.activeTab === 3

    ColumnLayout {
        id: svcsCol; width: parent.width; spacing: 8

        Text {
            Layout.fillWidth: true
            text: "󰅟  Service Management"
            font.pixelSize: 12; font.bold: true; color: mocha.subtext0
        }

        Repeater {
            model: dashboard.serviceList
            delegate: Rectangle {
                Layout.fillWidth: true; height: 40; radius: 6
                color: mocha.surface0
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4
                        color: modelData.status === "active" ? mocha.green : mocha.red }
                    Text { text: modelData.name; font.pixelSize: 11; font.bold: true; color: mocha.text }
                    Text { text: "(" + modelData.type + ")"; font.pixelSize: 9; color: mocha.overlay0 }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        height: 24; radius: 4; implicitWidth: svcBtnText.implicitWidth + 16
                        color: modelData.status === "active" ? mocha.red : mocha.green; opacity: 0.2
                        Text { id: svcBtnText; anchors.centerIn: parent
                            text: modelData.status === "active" ? "Stop" : "Start"
                            font.pixelSize: 9; color: modelData.status === "active" ? mocha.red : mocha.green }
                        MouseArea { anchors.fill: parent
                            onClicked: {
                                dashAction.command = [dashPoll.dashCtlPath, "service",
                                    modelData.status === "active" ? "stop" : "start",
                                    modelData.name, modelData.type]
                                dashAction.running = false; dashAction.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}

Flickable {
    anchors.fill: parent; anchors.margins: 8
    contentWidth: c2Col.width; contentHeight: c2Col.height
    clip: true; visible: dashboard.activeTab === 4

    ColumnLayout {
        id: c2Col; width: parent.width; spacing: 10

        Text {
            Layout.fillWidth: true
            text: "󱙝  C2 Frameworks"
            font.pixelSize: 12; font.bold: true; color: mocha.subtext0
        }

        Repeater {
            model: dashboard.c2List
            delegate: Rectangle {
                Layout.fillWidth: true; implicitHeight: c2Card.implicitHeight + 20
                radius: 8; color: mocha.surface0
                ColumnLayout {
                    id: c2Card
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 12; spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { width: 8; height: 8; radius: 4
                            color: modelData.status === "running" ? mocha.green : mocha.overlay0 }
                        Text { text: modelData.name; font.pixelSize: 12; font.bold: true; color: mocha.text }
                        Text { text: modelData.status; font.pixelSize: 9; color: mocha.overlay0 }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Rectangle {
                            height: 28; radius: 4; implicitWidth: 90; color: mocha.mauve; opacity: 0.15
                            Text { anchors.centerIn: parent; text: "Open Web UI"; font.pixelSize: 9; color: mocha.mauve }
                            MouseArea { anchors.fill: parent
                                onClicked: Quickshell.execDetached("waterfox", [modelData.web_ui]) }
                        }
                        Rectangle {
                            height: 28; radius: 4; implicitWidth: 60; color: mocha.teal; opacity: 0.15
                            Text { anchors.centerIn: parent; text: "Launch"; font.pixelSize: 9; color: mocha.teal }
                            MouseArea { anchors.fill: parent
                                onClicked: {
                                    dashAction.command = [dashPoll.dashCtlPath, "c2", "start", modelData.name]
                                    dashAction.running = false; dashAction.running = true
                                }
                            }
                        }
                        Rectangle {
                            height: 28; radius: 4; implicitWidth: 60; color: mocha.red; opacity: 0.15
                            visible: modelData.status === "running"
                            Text { anchors.centerIn: parent; text: "Stop"; font.pixelSize: 9; color: mocha.red }
                            MouseArea { anchors.fill: parent
                                onClicked: {
                                    dashAction.command = [dashPoll.dashCtlPath, "c2", "stop", modelData.name]
                                    dashAction.running = false; dashAction.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
            }
        }
    }

    Popup {
    id: ocResumePopup
    width: 300; height: 200
    x: parent.width / 2 - width / 2; y: parent.height / 2 - height / 2
    visible: false

    background: Rectangle {
        radius: 12; color: mocha.surface1
        border.width: 1; border.color: mocha.surface0
    }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 6
        Text { text: "Resume OpenCode"; font.pixelSize: 12; font.bold: true; color: mocha.text }
        Repeater {
            model: {
                var oc = []
                for (var i = 0; i < dashboard.agentSessions.length; i++) {
                    if (dashboard.agentSessions[i].agent === "opencode") oc.push(dashboard.agentSessions[i])
                }
                return oc.slice(0, 5)
            }
            delegate: Rectangle {
                height: 32; radius: 6; color: mocha.surface0
                Text { anchors.centerIn: parent
                    text: modelData.id.replace("stats-pid-","").substring(0,10)
                    font.pixelSize: 10; color: mocha.text }
                MouseArea { anchors.fill: parent
                    onClicked: {
                        var sid = modelData.started_at ? ("@" + modelData.started_at.substring(0,10)) : modelData.id
                        Quickshell.execDetached("ghostty", ["-e", "opencode", "--resume", sid])
                            || Quickshell.execDetached("kitty", ["sh", "-c", "opencode --resume " + sid])
                            || Quickshell.execDetached("alacritty", ["-e", "opencode", "--resume", sid])
                        ocResumePopup.visible = false
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; height: 1; color: mocha.surface0
        }
        Rectangle {
            height: 28; radius: 4; implicitWidth: 80; color: mocha.overlay0; opacity: 0.2
            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 10; color: mocha.text }
            MouseArea { anchors.fill: parent; onClicked: ocResumePopup.visible = false }
        }
    }
}
}