use ratatui::prelude::*;
use ratatui::widgets::*;

use crate::app::App;
use crate::widgets::table::styled_table;

pub fn render(area: Rect, buf: &mut Buffer, app: &App) {
    let data = match app.data {
        Some(ref d) => d,
        None => {
            let no_data = Paragraph::new("No data")
                .alignment(Alignment::Center)
                .block(Block::bordered().title("Network"));
            Widget::render(no_data, area, buf);
            return;
        }
    };

    let net = &data.network;

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Length(3),
            Constraint::Min(1),
        ])
        .split(area);

    // Ethernet & WiFi status header
    let eth_status = if net.ethernet.up { "UP" } else { "DOWN" };
    let wifi_str = if net.wifi.connected {
        format!("WiFi: {} ({}%)", net.wifi.ssid, net.wifi.strength)
    } else {
        "WiFi: disconnected".to_string()
    };
    let net_header = Paragraph::new(format!(
        "Ethernet: {} ({}) | {} | DNS: {}",
        eth_status, net.ethernet.ip, wifi_str, net.dns
    ))
    .style(Style::default().fg(Color::Rgb(139, 111, 239)).add_modifier(Modifier::BOLD))
    .alignment(Alignment::Center);
    Widget::render(net_header, chunks[0], buf);

    // nftables status
    let nft_status = if net.nftables.enabled {
        "Enabled"
    } else {
        "Disabled"
    };
    let nft_line = Paragraph::new(format!(
        "nftables: {} ({} rules)",
        nft_status, net.nftables.rules_count
    ))
    .style(Style::default().fg(Color::White))
    .alignment(Alignment::Center);
    Widget::render(nft_line, chunks[1], buf);

    // WireGuard tunnels table
    let wg_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(3)])
        .split(chunks[2]);

    let mut wg_rows: Vec<Vec<String>> = Vec::new();
    for tunnel in &net.wg {
        wg_rows.push(vec![
            tunnel.name.clone(),
            tunnel.status.clone(),
            tunnel.ip.clone(),
            tunnel.peers.len().to_string(),
        ]);
    }
    let wg_rows_ref: Vec<Vec<&str>> = wg_rows.iter()
        .map(|r| r.iter().map(|s| s.as_str()).collect())
        .collect();
    let wg_header = vec!["Tunnel", "Status", "IP", "Peers"];
    let wg_table = styled_table(wg_header, wg_rows_ref)
        .block(Block::bordered().title("WireGuard Tunnels"))
        .widths([
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
        ]);
    Widget::render(wg_table, wg_chunks[0], buf);

    // Peer details for first tunnel
    if let Some(tunnel) = net.wg.first() {
        let mut peer_rows: Vec<Vec<String>> = Vec::new();
        for peer in &tunnel.peers {
            let conn = if peer.connected { "Yes" } else { "No" };
            peer_rows.push(vec![
                peer.name.clone(),
                conn.to_string(),
                peer.latest_handshake.clone(),
            ]);
        }
        let peer_rows_ref: Vec<Vec<&str>> = peer_rows.iter()
            .map(|r| r.iter().map(|s| s.as_str()).collect())
            .collect();
        let peer_header = vec!["Peer", "Connected", "Handshake"];
        let peer_table = styled_table(peer_header, peer_rows_ref)
            .block(Block::bordered().title(format!("Peers — {}", tunnel.name)))
            .widths([
                Constraint::Ratio(1, 3),
                Constraint::Ratio(1, 3),
                Constraint::Ratio(1, 3),
            ]);
        Widget::render(peer_table, wg_chunks[1], buf);
    }
}
