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
                .block(Block::bordered().title("Sessions"));
            Widget::render(no_data, area, buf);
            return;
        }
    };

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(1)])
        .split(area);

    let header = Paragraph::new("SESSIONS — Tmux Sessions")
        .style(Style::default().fg(Color::Rgb(139, 111, 239)).add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center);
    Widget::render(header, chunks[0], buf);

    let mut rows: Vec<Vec<String>> = Vec::new();
    for sess in &data.tmux {
        let attached = if sess.attached { "Yes" } else { "No" };
        rows.push(vec![
            sess.session.clone(),
            sess.windows.to_string(),
            attached.to_string(),
        ]);
    }
    let rows_ref: Vec<Vec<&str>> = rows.iter()
        .map(|r| r.iter().map(|s| s.as_str()).collect())
        .collect();

    let session_header = vec!["Session", "Windows", "Attached"];
    let table = styled_table(session_header, rows_ref)
        .block(Block::bordered().title("Tmux"))
        .widths([
            Constraint::Ratio(2, 4),
            Constraint::Ratio(1, 4),
            Constraint::Ratio(1, 4),
        ]);
    Widget::render(table, chunks[1], buf);
}
