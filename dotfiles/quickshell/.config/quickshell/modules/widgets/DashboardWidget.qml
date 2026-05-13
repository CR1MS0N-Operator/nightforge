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
    property var containers: []
    property var vms: []
    property string cpuStr: "--%"
    property string ramStr: "--"
    property string uptimeStr: "--"
    property string localIp: "--"
    property string wgStatus: "Disconnected"
    property string dnsServer: "--"
    property string opsContainerCount: "--"
    property string opsVmCount: "--"
    property string opsUptime: "--"
    property string serviceStr: ""
    property string c2Status: ""
    property var agentSessions: []
    property int activeGraphTab: 0


    // =========================================================
    // Parse Functions
    // =========================================================
    function parseContainers(text) {
        var t = text.trim()
        if (t === "") { containers = []; return }
        var lines = t.split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].split("|")
            if (parts.length >= 3) {
                var ports = parts.length >= 4 ? parts[3] : ""
                var status = parts[2]
                var isUp = status.indexOf("Up") === 0
                result.push({ name: parts[0], image: parts[1], status: status, ports: ports, isUp: isUp })
            }
        }
        containers = result
    }

    function parseVMs(text) {
        var lines = text.trim().split("\n")
        var result = []
        for (var i = 2; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") continue
            var parts = line.split(/\s+/)
            if (parts.length >= 3) {
                result.push({ id: parts[0], name: parts[1], state: parts.slice(2).join(" ") })
            } else if (parts.length >= 2) {
                result.push({ id: parts[0], name: parts[1], state: "unknown" })
            }
        }
        vms = result
    }

    function parseSys(text) {
        var parts = text.trim().split("|")
        if (parts.length >= 3) {
            cpuStr = parts[0] + "%"
            ramStr = parts[2] + "/" + parts[3] + " GB"
        }
    }

    function parseUptime(text) {
        var secs = parseFloat(text.trim().split(" ")[0]) || 0
        var d = Math.floor(secs / 86400)
        var h = Math.floor((secs % 86400) / 3600)
        var m = Math.floor((secs % 3600) / 60)
        uptimeStr = d + "d " + h + "h " + m + "m"
    }

    function parseOpsData(text) {
        var lines = text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim()
            if (l.indexOf("NET=") === 0) dashboard.localIp = l.substring(4)
            else if (l.indexOf("WG=") === 0) dashboard.wgStatus = l.substring(3)
            else if (l.indexOf("DNS=") === 0) dashboard.dnsServer = l.substring(4)
            else if (l.indexOf("CT=") === 0) dashboard.opsContainerCount = l.substring(3)
            else if (l.indexOf("VM=") === 0) dashboard.opsVmCount = l.substring(3)
            else if (l.indexOf("UP=") === 0) dashboard.opsUptime = l.substring(3)
        }
    }

    function parseServices(text) {
        var lines = text.trim().split("\n")
        var parts = []
        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim().split("=")
            if (l.length >= 2) parts.push({ name: l[0], status: l.slice(1).join("=") })
        }
        dashboard.serviceStr = JSON.stringify(parts)
    }

    // =========================================================
    // Data Processes
    // =========================================================
    Process {
        id: containerPoll; running: true
        command: ["sh", "-c", "podman ps --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' 2>/dev/null || echo ''"]
        stdout: StdioCollector { onStreamFinished: parseContainers(text) }
    }
    Process {
        id: vmPoll; running: true
        command: ["sh", "-c", "virsh list --all 2>/dev/null || echo ''"]
        stdout: StdioCollector { onStreamFinished: parseVMs(text) }
    }
    Process {
        id: sysPoll; running: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/qs-watcher", "fetch", "sys"]
        stdout: StdioCollector { onStreamFinished: parseSys(text) }
    }
    Process {
        id: uptimePoll; running: true
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector { onStreamFinished: parseUptime(text) }
    }
    Process {
        id: opsDataPoll; running: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/ops-data.sh"]
        stdout: StdioCollector { onStreamFinished: parseOpsData(text) }
    }
    Process {
        id: opsSvcPoll; running: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/ops-services.sh"]
        stdout: StdioCollector { onStreamFinished: parseServices(text) }
    }
    Process {
        id: c2Poll; running: true
        command: ["sh", "-c", "C2S='[]'; [ -f /opt/mythic/.env ] && C2=$(echo 'Mythic' | jq -Rsc '{name:.,status:\"active\"}' 2>/dev/null) && C2S=\"[$C2]\"; echo \"$C2S\""]
        stdout: StdioCollector { onStreamFinished: { var t = text.trim(); if (t) dashboard.c2Status = t; } }
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
            containerPoll.running = false; containerPoll.running = true
            vmPoll.running = false; vmPoll.running = true
            sysPoll.running = false; sysPoll.running = true
            uptimePoll.running = false; uptimePoll.running = true
            opsDataPoll.running = false; opsDataPoll.running = true
            opsSvcPoll.running = false; opsSvcPoll.running = true
            c2Poll.running = false; c2Poll.running = true
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
                            containerPoll.running = false; containerPoll.running = true
                            vmPoll.running = false; vmPoll.running = true
                            sysPoll.running = false; sysPoll.running = true
                            uptimePoll.running = false; uptimePoll.running = true
                            opsDataPoll.running = false; opsDataPoll.running = true
                            opsSvcPoll.running = false; opsSvcPoll.running = true
                        }
                    }
                }
            }

            // --- Main Content ---
            // Containers + VMs row
            RowLayout {
                id: mainContent
                Layout.fillWidth: true
                Layout.preferredHeight: 250
                spacing: 12

                // --- Containers Panel ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "  Containers"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: containers.length
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black
                                color: containers.length > 0 ? mocha.green : mocha.overlay0
                            }
                        }

                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 4
                            model: containers

                            delegate: Rectangle {
                                width: parent ? parent.width : 0
                                height: 36; radius: 8
                                color: mocha.surface1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 6
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: modelData.isUp ? mocha.green : mocha.red
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text {
                                            text: modelData.name
                                            font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Bold
                                            color: mocha.text
                                        }
                                        Text {
                                            text: modelData.image
                                            font.family: "JetBrains Mono"; font.pixelSize: 9
                                            color: mocha.overlay0; elide: Text.ElideRight
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: modelData.ports
                                        font.family: "JetBrains Mono"; font.pixelSize: 9
                                        color: mocha.teal; elide: Text.ElideRight
                                        visible: modelData.ports !== ""
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "No running containers"
                                font.family: "JetBrains Mono"; font.pixelSize: 11
                                color: mocha.overlay0
                                visible: parent.count === 0
                            }
                        }
                    }
                }

                // --- VMs Panel ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "󰻉  Virtual Machines"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
                                color: mocha.text
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: vms.length
                                font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black
                                color: vms.length > 0 ? mocha.mauve : mocha.overlay0
                            }
                        }

                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 4
                            model: vms

                            delegate: Rectangle {
                                width: parent ? parent.width : 0
                                height: 36; radius: 8
                                color: mocha.surface1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                                    Rectangle {
                                        width: 8; height: 8; radius: 4
                                        color: modelData.state === "running" ? mocha.green : mocha.overlay0
                                    }
                                    Text {
                                        text: modelData.name
                                        font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Bold
                                        color: mocha.text; Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData.state
                                        font.family: "JetBrains Mono"; font.pixelSize: 10
                                        color: modelData.state === "running" ? mocha.green : mocha.overlay0
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "No VMs configured"
                                font.family: "JetBrains Mono"; font.pixelSize: 11
                                color: mocha.overlay0
                                visible: parent.count === 0
                            }
                        }
                    }
                }
            }

            // --- Operations Section ---
            Rectangle {
                Layout.fillWidth: true
                Layout.minimumHeight: 360
                implicitHeight: opsCol.implicitHeight + 32
                radius: 12
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.5)

                ColumnLayout {
                    id: opsCol
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.top: parent.top; anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "󱛛  Operations"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 14; font.bold: true
                        color: mocha.text
                    }

                    // Network & Environment
                    Rectangle {
                        Layout.fillWidth: true; radius: 10
                        implicitHeight: networkCol.implicitHeight + 24
                        color: mocha.surface1
                        ColumnLayout {
                            id: networkCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 12
                            spacing: 8
                            Text {
                                text: "󰈀  Network & Environment"
                                font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true
                                color: mocha.subtext0
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12

                                Text { text: "IP:"; font.pixelSize: 11; color: mocha.overlay0 }
                                Text { text: dashboard.localIp; font.pixelSize: 11; color: mocha.text }
                                Item { Layout.fillWidth: true }
                                Text { text: "WG:"; font.pixelSize: 11; color: mocha.overlay0 }
                                Rectangle { width: 8; height: 8; radius: 4; color: dashboard.wgStatus === "Connected" ? mocha.green : mocha.red }
                                Text { text: dashboard.wgStatus; font.pixelSize: 11; color: dashboard.wgStatus === "Connected" ? mocha.green : mocha.subtext0 }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                Text { text: "DNS:"; font.pixelSize: 11; color: mocha.overlay0 }
                                Text { text: dashboard.dnsServer; font.pixelSize: 11; color: mocha.text }
                            }
                        }
                    }

                    // Service Status
                    Rectangle {
                        Layout.fillWidth: true; radius: 10
                        implicitHeight: svcCol.implicitHeight + 24
                        color: mocha.surface1
                        ColumnLayout {
                            id: svcCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 12
                            spacing: 8
                            Text {
                                text: "󰅟  Service Status"
                                font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true
                                color: mocha.subtext0
                            }
                            Flow {
                                Layout.fillWidth: true; spacing: 10
                                Repeater {
                                    model: {
                                        try { return JSON.parse(dashboard.serviceStr); } catch(e) { return []; }
                                    }
                                    delegate: RowLayout {
                                        spacing: 5
                                        Rectangle { width: 8; height: 8; radius: 4; color: modelData.status === "active" ? mocha.green : mocha.red }
                                        Text { text: modelData.name; font.pixelSize: 11; color: modelData.status === "active" ? mocha.text : mocha.overlay0 }
                                    }
                                }
                            }
                        }
                    }

                    // C2 Frameworks
                    Rectangle {
                        Layout.fillWidth: true; radius: 10
                        implicitHeight: c2Col.implicitHeight + 24
                        color: mocha.surface1
                        ColumnLayout {
                            id: c2Col
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 12
                            spacing: 8
                            Text {
                                text: "󱙝  C2 Frameworks"
                                font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true
                                color: mocha.subtext0
                            }
                            Text {
                                text: {
                                    try { var c = JSON.parse(dashboard.c2Status); return c.length > 0 ? c.map(function(x) { return x.name + ": " + x.status; }).join("  ·  ") : "None active"; }
                                    catch(e) { return "None configured"; }
                                }
                                font.pixelSize: 11; color: mocha.text
                            }
                        }
                    }

                    // --- Agent Sessions ---
                    Rectangle {
                        Layout.fillWidth: true
                        radius: 10
                        color: mocha.surface1
                        implicitHeight: sessionsCol.implicitHeight + 24

                        ColumnLayout {
                            id: sessionsCol
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.top: parent.top; anchors.margins: 12
                            spacing: 10

                            Text {
                                text: "󱚝  Agent Sessions"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 12; font.bold: true
                                color: mocha.subtext0
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Repeater {
                                    model: ["Timeline", "Tool Usage", "Model Routing"]
                                    delegate: Rectangle {
                                        height: 26; radius: 6
                                        color: dashboard.activeGraphTab === index
                                            ? Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.3)
                                            : mocha.surface0
                                        implicitWidth: tabText.implicitWidth + 16
                                        Text {
                                            id: tabText
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 10; font.bold: dashboard.activeGraphTab === index
                                            color: dashboard.activeGraphTab === index ? mocha.mauve : mocha.text
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: dashboard.activeGraphTab = index
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 150; radius: 8
                                color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.5)
                                clip: true

                                Flickable {
                                    anchors.fill: parent; anchors.margins: 6
                                    contentWidth: timelineCol.width
                                    contentHeight: timelineCol.height
                                    clip: true
                                    visible: dashboard.activeGraphTab === 0
                                    Column {
                                        id: timelineCol
                                        width: parent.width
                                        spacing: 4
                                        Repeater {
                                            model: dashboard.agentSessions.slice(0, 20)
                                            delegate: Item {
                                                width: parent ? parent.width : 0
                                                height: 22
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.max(8, Math.min(modelData.uptime_seconds / 15, parent.width - 120))
                                                    height: 14; radius: 3
                                                    color: mocha.overlay0
                                                    opacity: 0.3
                                                }
                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.max(4, Math.min(modelData.uptime_seconds / 15, parent.width - 120))
                                                    height: 6; radius: 3
                                                    color: modelData.status === "active" ? mocha.green : mocha.mauve
                                                    opacity: 0.8
                                                }
                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: 4
                                                    spacing: 4
                                                    Text {
                                                        text: modelData.agent === "opencode" ? "󰨞" : "󰣇"
                                                        font.pixelSize: 9; color: mocha.text
                                                    }
                                                    Text {
                                                        text: modelData.id.replace("stats-pid-","").substring(0,6)
                                                        font.pixelSize: 9; color: mocha.text
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: Math.round(modelData.uptime_seconds/60) + "m"
                                                        font.pixelSize: 8; color: mocha.overlay0
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            text: "No sessions"
                                            font.pixelSize: 10; color: mocha.overlay0
                                            visible: parent.children.length === 0
                                        }
                                    }
                                }

                                Flickable {
                                    anchors.fill: parent; anchors.margins: 6
                                    contentWidth: toolsCol.width
                                    contentHeight: toolsCol.height
                                    clip: true
                                    visible: dashboard.activeGraphTab === 1
                                    Column {
                                        id: toolsCol
                                        width: parent.width
                                        spacing: 4
                                        property var totals: {
                                            var t = {};
                                            for (var i = 0; i < dashboard.agentSessions.length; i++) {
                                                var s = dashboard.agentSessions[i];
                                                for (var k in s.tools) { t[k] = (t[k] || 0) + s.tools[k]; }
                                            }
                                            return t;
                                        }
                                        property int maxCalls: {
                                            var m = 1;
                                            for (var k in totals) { m = Math.max(m, totals[k]); }
                                            return m;
                                        }
                                        Repeater {
                                            model: { var k = []; for (var t in toolsCol.totals) { k.push(t); } return k; }
                                            delegate: RowLayout {
                                                width: parent ? parent.width : 0
                                                height: 16; spacing: 4
                                                Text {
                                                    text: modelData; width: 90
                                                    font.pixelSize: 8; color: mocha.overlay0
                                                    elide: Text.ElideRight
                                                }
                                                Rectangle {
                                                    height: 10; radius: 3
                                                    width: Math.max(4, (toolsCol.totals[modelData]/toolsCol.maxCalls) * (parent.width - 130))
                                                    color: mocha.mauve
                                                }
                                                Text {
                                                    text: toolsCol.totals[modelData]
                                                    font.pixelSize: 8; color: mocha.text
                                                }
                                            }
                                        }
                                        Text {
                                            text: "No tool data"
                                            font.pixelSize: 10; color: mocha.overlay0
                                            visible: { var c = 0; for (var t in toolsCol.totals) { c++; } return c === 0; }
                                        }
                                    }
                                }

                                Flickable {
                                    anchors.fill: parent; anchors.margins: 6
                                    contentWidth: modelsFlow.width
                                    contentHeight: modelsFlow.height
                                    clip: true
                                    visible: dashboard.activeGraphTab === 2
                                    Flow {
                                        id: modelsFlow
                                        width: parent.width
                                        spacing: 6
                                        property var counts: {
                                            var c = {};
                                            for (var i = 0; i < dashboard.agentSessions.length; i++) {
                                                var m = dashboard.agentSessions[i].model || "unknown";
                                                c[m] = (c[m] || 0) + 1;
                                            }
                                            return c;
                                        }
                                        Repeater {
                                            model: { var k = []; for (var m in modelsFlow.counts) { k.push(m); } return k; }
                                            delegate: Rectangle {
                                                height: 28; radius: 6
                                                color: mocha.surface0
                                                implicitWidth: pillRow.implicitWidth + 12
                                                RowLayout {
                                                    id: pillRow
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Text {
                                                        text: modelData
                                                        font.pixelSize: 9; font.bold: true
                                                        color: mocha.text; elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: "x" + modelsFlow.counts[modelData]
                                                        font.pixelSize: 9; color: mocha.mauve
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            text: "No data"
                                            font.pixelSize: 10; color: mocha.overlay0
                                            visible: { var c = 0; for (var m in modelsFlow.counts) { c++; } return c === 0; }
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "No graph data"
                                    font.pixelSize: 11; color: mocha.overlay0
                                    visible: dashboard.agentSessions.length === 0
                                }
                            }

                            ListView {
                                id: sessionsList
                                Layout.fillWidth: true
                                height: Math.min(dashboard.agentSessions.length * 38, 150)
                                clip: true; spacing: 4
                                model: dashboard.agentSessions

                                delegate: Rectangle {
                                    width: parent ? parent.width : 0
                                    height: 38; radius: 6
                                    color: mocha.surface0
                                    clip: true

                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 6; spacing: 6
                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            color: modelData.status === "active" ? mocha.green : mocha.overlay0
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            Text {
                                                Layout.fillWidth: true
                                                text: (modelData.agent === "opencode" ? "󰨞 " : "󰣇 ") +
                                                      (modelData.agent === "opencode" ? "OpenCode " : "Hermes ") +
                                                      modelData.id.replace("stats-pid-", "").substring(0, 8)
                                                font.family: "JetBrains Mono"; font.pixelSize: 10; font.bold: true
                                                color: mocha.text
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.model + "  ·  " + modelData.total_calls + " calls  ·  " +
                                                      Math.round(modelData.uptime_seconds / 60) + "m"
                                                font.pixelSize: 9
                                                color: mocha.overlay0
                                                elide: Text.ElideRight
                                            }
                                        }
                                        Text {
                                            text: {
                                                if (modelData.cost_saved > 0) return "󰄪 $" + modelData.cost_saved.toFixed(2)
                                                if (modelData.tokens_saved > 0) return "󰄪 " + modelData.tokens_saved + " tok"
                                                return ""
                                            }
                                            font.pixelSize: 9
                                            color: mocha.teal
                                            visible: modelData.tokens_saved > 0 || modelData.cost_saved > 0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Operations Brief
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16; Layout.bottomMargin: 4
                        Text {
                            text: "󰻠 CT: " + dashboard.opsContainerCount + "  ·  󰻉 VM: " + dashboard.opsVmCount + "  ·  󰔟 " + dashboard.opsUptime
                            font.pixelSize: 11
                            color: mocha.overlay0
                        }
                    }
                }
            }

            // --- System Footer ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 10
                color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.3)

                RowLayout {
                    anchors.fill: parent; anchors.margins: 10
                    spacing: 16
                    Text {
                        text: "󰻠 CPU: " + cpuStr
                        font.family: "JetBrains Mono"; font.pixelSize: 10
                        color: mocha.subtext0
                    }
                    Text {
                        text: " RAM: " + ramStr
                        font.family: "JetBrains Mono"; font.pixelSize: 10
                        color: mocha.subtext0
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "󰔟 " + uptimeStr
                        font.family: "JetBrains Mono"; font.pixelSize: 10
                        color: mocha.overlay0
                    }
                }
            }
        }
    }
}
