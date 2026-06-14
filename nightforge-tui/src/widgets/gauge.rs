use ratatui::prelude::*;
use ratatui::widgets::*;

use crate::theme;

pub fn render_gauge(area: Rect, buf: &mut Buffer, label: &str, value: &str, percent: f64, color: Color) {
    let pct = (percent as u16).min(100);
    let gauge = Gauge::default()
        .block(Block::bordered().title(label))
        .gauge_style(Style::default().fg(color).bg(Color::Rgb(13, 15, 26)))
        .percent(pct)
        .label(Span::styled(
            format!("{} {pct}%", value),
            Style::default().fg(theme::TEXT_LIGHT),
        ));
    Widget::render(gauge, area, buf);
}
