use ratatui::prelude::*;
use ratatui::widgets::*;

use crate::app::App;
use crate::widgets::gauge::render_gauge;

pub fn render(area: Rect, buf: &mut Buffer, app: &App) {
    let data = match app.data {
        Some(ref d) => d,
        None => {
            let no_data = Paragraph::new("No data")
                .alignment(Alignment::Center)
                .block(Block::bordered().title("Monitor"));
            Widget::render(no_data, area, buf);
            return;
        }
    };

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Length(5),
            Constraint::Min(1),
        ])
        .split(area);

    // Header
    let header = Paragraph::new("MONITOR — System Status")
        .style(Style::default().fg(Color::Rgb(139, 111, 239)).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center);
    Widget::render(header, chunks[0], buf);

    // Gauges row
    let gauge_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Ratio(1, 3),
            Constraint::Ratio(1, 3),
            Constraint::Ratio(1, 3),
        ])
        .split(chunks[1]);

    let container_running = data.containers.iter().filter(|c| c.status == "running").count();
    let container_total = data.containers.len();
    let contain_pct = if container_total > 0 {
        (container_running as f64 / container_total as f64) * 100.0
    } else {
        0.0
    };

    let vm_running = data.vms.iter().filter(|v| v.state == "running").count();
    let vm_total = data.vms.len();
    let vm_pct = if vm_total > 0 {
        (vm_running as f64 / vm_total as f64) * 100.0
    } else {
        0.0
    };

    let services_active = data.services.iter().filter(|s| s.status == "active").count();
    let services_total = data.services.len();
    let svc_pct = if services_total > 0 {
        (services_active as f64 / services_total as f64) * 100.0
    } else {
        0.0
    };

    render_gauge(
        gauge_chunks[0],
        buf,
        "Containers (running)",
        &format!("{}/{}", container_running, container_total),
        contain_pct,
        Color::Green,
    );
    render_gauge(
        gauge_chunks[1],
        buf,
        "VMs (running)",
        &format!("{}/{}", vm_running, vm_total),
        vm_pct,
        Color::Blue,
    );
    render_gauge(
        gauge_chunks[2],
        buf,
        "Services (active)",
        &format!("{}/{}", services_active, services_total),
        svc_pct,
        Color::Cyan,
    );

    // Service list
    let mut svc_text = String::new();
    for svc in &data.services {
        let status_icon = if svc.status == "active" { "✓" } else { "✗" };
        svc_text.push_str(&format!(
            "{}  {}  [{}]\n",
            status_icon, svc.name, svc.service_type
        ));
    }
    let svc_para = Paragraph::new(svc_text)
        .block(Block::bordered().title("Services"))
        .style(Style::default().fg(Color::White));
    Widget::render(svc_para, chunks[2], buf);
}
