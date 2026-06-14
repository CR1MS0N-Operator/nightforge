use ratatui::prelude::*;
use ratatui::widgets::*;

use crate::theme;

pub fn styled_table<'a>(header: Vec<&'a str>, rows: Vec<Vec<&'a str>>) -> Table<'a> {
    let header_cells: Vec<Cell<'a>> = header
        .iter()
        .map(|h| {
            Cell::from(*h).style(
                Style::default()
                    .fg(theme::PRIMARY)
                    .add_modifier(Modifier::BOLD),
            )
        })
        .collect();
    let header_row = Row::new(header_cells);

    let data_rows: Vec<Row<'a>> = rows
        .iter()
        .enumerate()
        .map(|(i, row)| {
            let cells: Vec<Cell<'a>> = row.iter().map(|c| Cell::from(*c)).collect();
            let style = if i % 2 == 0 {
                Style::default().bg(Color::Rgb(13, 15, 26))
            } else {
                Style::default().bg(Color::Rgb(20, 22, 36))
            };
            Row::new(cells).style(style)
        })
        .collect();

    let widths: Vec<Constraint> = (0..header.len()).map(|_| Constraint::Min(10)).collect();

    Table::new(data_rows, widths)
        .header(header_row)
        .block(Block::bordered())
}
