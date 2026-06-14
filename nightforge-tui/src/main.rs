mod app;
mod poller;
mod tabs;
mod theme;
mod widgets;

use std::io;
use std::time::Duration;

use crossterm::event::{self, Event, KeyCode};
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use crossterm::execute;
use ratatui::backend::CrosstermBackend;
use ratatui::prelude::*;
use ratatui::widgets::*;
use ratatui::Terminal;

use app::{App, TabType};
use poller::{poll_dashboard, poll_euphrates};

fn main() -> io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    execute!(stdout, crossterm::event::EnableMouseCapture)?;

    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();

    // Initial poll — single attempt
    match poll_dashboard() {
        Ok(data) => app.set_data(data),
        Err(e) => {
            eprintln!("Initial poll failed: {}", e);
            app.set_error(format!("Cannot connect to dashboard-ctl — {}", e));
        }
    }

    // Initial Euphrates poll
    match poll_euphrates() {
        Ok(data) => app.set_euphrates(data),
        Err(e) => {
            eprintln!("Euphrates poll failed: {}", e);
            app.set_euphrates_error(e);
        }
    }

    // Event loop
    loop {
        terminal.draw(|f| {
            let area = f.area();
            let buf = f.buffer_mut();
            render(area, buf, &mut app);
        })?;

        if event::poll(Duration::from_secs(5))? {
            match event::read()? {
                Event::Key(key) => match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    KeyCode::Tab | KeyCode::Right => app.next_tab(),
                    KeyCode::Left => app.previous_tab(),
                    KeyCode::Char('r') => {
                        match poll_dashboard() {
                            Ok(data) => {
                                app.set_data(data);
                                app.error = None;
                            }
                            Err(e) => app.set_error(e),
                        }
                        // Also refresh Euphrates on manual refresh
                        match poll_euphrates() {
                            Ok(data) => app.set_euphrates(data),
                            Err(e) => app.set_euphrates_error(e),
                        }
                    }
                    _ => {}
                },
                Event::Mouse(_) => {
                    // Mouse clicks are handled by ratatui's built-in mouse support
                }
                _ => {}
            }
        } else {
            // Auto-refresh every 5 seconds
            match poll_dashboard() {
                Ok(data) => app.set_data(data),
                Err(e) => {
                    eprintln!("Poll error: {}", e);
                }
            }
            // Also refresh Euphrates on auto-refresh
            match poll_euphrates() {
                Ok(data) => app.set_euphrates(data),
                Err(e) => app.set_euphrates_error(e),
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    execute!(terminal.backend_mut(), crossterm::event::DisableMouseCapture)?;
    terminal.show_cursor()?;

    Ok(())
}

fn render(area: Rect, buf: &mut Buffer, app: &mut App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(1)])
        .split(area);

    // Tab bar
    let tab_types = TabType::all();
    let tab_names: Vec<&str> = tab_types.iter().map(|t| t.name()).collect();
    let tabs = Tabs::new(tab_names)
        .select(app.current_tab)
        .block(Block::bordered().title("NightForge"))
        .style(Style::default().fg(Color::White))
        .highlight_style(Style::default().fg(Color::Rgb(139, 111, 239)));
    Widget::render(tabs, chunks[0], buf);

    let content_area = chunks[1];

    // Loading state
    if app.loading {
        let spinner = Paragraph::new("Loading...")
            .alignment(Alignment::Center)
            .block(Block::bordered().title("NightForge v2"));
        Widget::render(spinner, content_area, buf);
        return;
    }

    match TabType::all().get(app.current_tab) {
        Some(TabType::Dashboard) => tabs::dashboard::render(content_area, buf, app),
        Some(TabType::Network) => tabs::network::render(content_area, buf, app),
        Some(TabType::Monitor) => tabs::monitor::render(content_area, buf, app),
        Some(TabType::Sessions) => tabs::sessions::render(content_area, buf, app),
        Some(TabType::Osint) => tabs::osint::render(content_area, buf, app),
        None => {}
    }
}
