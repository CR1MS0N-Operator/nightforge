use ratatui::prelude::*;
use ratatui::widgets::*;

use crate::app::App;
use crate::theme;
use crate::widgets::table::styled_table;

pub fn render(area: Rect, buf: &mut Buffer, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(1)])
        .split(area);

    let header = Paragraph::new("OSINT — Research Intelligence")
        .style(Style::default().fg(theme::PRIMARY).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center);
    Widget::render(header, chunks[0], buf);

    let body_area = chunks[1];

    if let Some(ref err) = app.euphrates_error {
        let msg = Paragraph::new(format!("Euphrates unavailable: {}", err))
            .alignment(Alignment::Center)
            .style(Style::default().fg(theme::ERROR))
            .block(Block::bordered().title("OSINT Integration").border_style(Style::default().fg(theme::ACCENT)));
        Widget::render(msg, body_area, buf);
        return;
    }

    let ed = match app.euphrates {
        Some(ref d) => d,
        None => {
            let placeholder = Paragraph::new("Connecting to Euphrates...")
                .alignment(Alignment::Center)
                .block(Block::bordered().title("OSINT Integration").border_style(Style::default().fg(theme::ACCENT)));
            Widget::render(placeholder, body_area, buf);
            return;
        }
    };

    // Split: CVEs on left, feeds on right
    let panes = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Ratio(1, 2), Constraint::Ratio(1, 2)])
        .split(body_area);

    // --- CVE table ---
    let cve_header = vec!["CVE ID", "Score", "Class", "Source"];
    let cve_rows: Vec<Vec<String>> = ed.cves.iter().map(|c| {
        vec![
            c.id.clone(),
            format!("{:.1}", c.cvss_score),
            c.vulnerability_class.clone(),
            c.source.clone(),
        ]
    }).collect();

    let cve_rows_ref: Vec<Vec<&str>> = cve_rows.iter()
        .map(|r| r.iter().map(|s| s.as_str()).collect())
        .collect();

    let cve_table = styled_table(cve_header, cve_rows_ref)
        .block(
            Block::bordered()
                .border_style(Style::default().fg(theme::PRIMARY))
                .title("CVEs — High Signal"),
        )
        .widths([
            Constraint::Ratio(2, 6),
            Constraint::Ratio(1, 6),
            Constraint::Ratio(2, 6),
            Constraint::Ratio(1, 6),
        ]);
    Widget::render(cve_table, panes[0], buf);

    // --- Feeds placeholder ---
    let mut feed_lines: Vec<Line> = Vec::new();
    if ed.feeds.is_empty() {
        feed_lines.push(
            Line::from(vec![
                Span::raw("No feed items. RSS polling not yet wired."),
            ])
            .style(Style::default().fg(theme::ACCENT)),
        );
    } else {
        for item in &ed.feeds {
            if let Some(text) = item.get("title").and_then(|v| v.as_str()) {
                feed_lines.push(Line::from(Span::raw(text)));
            }
        }
    }

    let feeds_block = Paragraph::new(feed_lines)
        .block(
            Block::bordered()
                .border_style(Style::default().fg(theme::ACCENT))
                .title("Feeds"),
        )
        .style(Style::default().fg(theme::TEXT_LIGHT));
    Widget::render(feeds_block, panes[1], buf);
}
