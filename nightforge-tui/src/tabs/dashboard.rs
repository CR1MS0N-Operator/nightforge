use ratatui::prelude::*;
use ratatui::widgets::*;
use tui_globe::{Camera, Globe, MapData};

use crate::app::App;
use crate::theme;
use crate::widgets::gauge::render_gauge;
use crate::widgets::table::styled_table;

pub fn render(area: Rect, buf: &mut Buffer, app: &App) {
    let data = match app.data {
        Some(ref d) => d,
        None => {
            let no_data = Paragraph::new("No data")
                .alignment(Alignment::Center)
                .block(
                    Block::bordered()
                        .border_style(Style::default().fg(theme::ACCENT))
                        .title("DASHBOARD — NightForge v2"),
                );
            Widget::render(no_data, area, buf);
            return;
        }
    };

    // Header
    let header = Paragraph::new("DASHBOARD — NightForge v2")
        .style(
            Style::default()
                .fg(theme::PRIMARY)
                .add_modifier(Modifier::BOLD),
        )
        .alignment(Alignment::Center);

    // Layout: header (3), top half (globe + gauges), bottom half (tables)
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Ratio(1, 2),
            Constraint::Ratio(1, 2),
        ])
        .split(area);

    Widget::render(header, chunks[0], buf);

    // Top half: globe (left) + gauges (right)
    let top = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Ratio(1, 2), Constraint::Ratio(1, 2)])
        .split(chunks[1]);

    // Globe widget (wireframe, no peer data for now)
    let map_data = MapData::embedded();
    let globe = Globe::new(&map_data, Camera::default());
    Widget::render(globe, top[0], buf);

    // Gauges in right half
    let gauge_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
        ])
        .split(top[1]);

    let container_count = data.containers.len();
    let vm_count = data.vms.len();
    let c2_online = data.c2.iter().filter(|c| c.status == "online").count();
    let c2_total = data.c2.len();
    let c2_pct = if c2_total > 0 {
        (c2_online as f64 / c2_total as f64) * 100.0
    } else {
        0.0
    };

    render_gauge(gauge_chunks[0], buf, "CPU", "—", 0.0, theme::ACCENT);
    render_gauge(
        gauge_chunks[1],
        buf,
        "Containers",
        &container_count.to_string(),
        (container_count as f64 / 10.0 * 100.0).min(100.0),
        theme::SUCCESS,
    );
    render_gauge(
        gauge_chunks[2],
        buf,
        "VMs",
        &vm_count.to_string(),
        (vm_count as f64 / 5.0 * 100.0).min(100.0),
        theme::PRIMARY,
    );
    render_gauge(
        gauge_chunks[3],
        buf,
        "C2 Status",
        &format!("{}/{}", c2_online, c2_total),
        c2_pct,
        theme::WARNING,
    );

    // Bottom half: C2 table (left) + containers table (right)
    let bottom = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Ratio(1, 2), Constraint::Ratio(1, 2)])
        .split(chunks[2]);

    // C2 table
    let c2_header = vec!["Framework", "Web UI", "Status"];
    let c2_rows: Vec<Vec<&str>> = data
        .c2
        .iter()
        .map(|c| vec![c.name.as_str(), c.web_ui.as_str(), c.status.as_str()])
        .collect();
    let c2_table = styled_table(c2_header, c2_rows)
        .block(
            Block::bordered()
                .border_style(Style::default().fg(theme::PRIMARY))
                .title("C2 Frameworks"),
        )
        .widths([
            Constraint::Ratio(1, 4),
            Constraint::Ratio(2, 4),
            Constraint::Ratio(1, 4),
        ]);
    Widget::render(c2_table, bottom[0], buf);

    // Container list
    let cont_header = vec!["Name", "Status", "Ports"];
    let cont_rows: Vec<Vec<&str>> = data
        .containers
        .iter()
        .map(|c| vec![c.name.as_str(), c.status.as_str(), c.ports.as_str()])
        .collect();
    let cont_table = styled_table(cont_header, cont_rows)
        .block(
            Block::bordered()
                .border_style(Style::default().fg(theme::ACCENT))
                .title("Containers"),
        )
        .widths([
            Constraint::Ratio(2, 5),
            Constraint::Ratio(1, 5),
            Constraint::Ratio(2, 5),
        ]);
    Widget::render(cont_table, bottom[1], buf);
}
