mod app;
mod poller;
mod tabs;
mod theme;
mod widgets;

use std::io;
use std::time::Duration;

use crossterm::event::{DisableMouseCapture, EnableMouseCapture, Event, EventStream, KeyCode};
use crossterm::terminal::disable_raw_mode;
use crossterm::terminal::enable_raw_mode;
use crossterm::terminal::EnterAlternateScreen;
use crossterm::terminal::LeaveAlternateScreen;
use crossterm::execute;
use futures::StreamExt;
use ratatui::backend::CrosstermBackend;
use ratatui::prelude::*;
use ratatui::widgets::*;
use ratatui::Terminal;

use app::{App, TabType};
use poller::{poll_dashboard, poll_euphrates};
use theme::Theme;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let theme = Theme::load().unwrap_or_else(|_| Theme::default_fallback());

    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    execute!(stdout, EnableMouseCapture)?;

    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();

    // Initial poll — single attempt
    match poll_dashboard().await {
        Ok(data) => app.set_data(data),
        Err(e) => {
            eprintln!("Initial poll failed: {}", e);
            app.set_error(format!("Cannot connect to dashboard-ctl — {}", e));
        }
    }

    // Initial Euphrates poll
    match poll_euphrates().await {
        Ok(data) => app.set_euphrates(data),
        Err(e) => {
            eprintln!("Euphrates poll failed: {}", e);
            app.set_euphrates_error(e);
        }
    }

    let mut event_stream = EventStream::new();
    let mut poll_interval = tokio::time::interval(Duration::from_secs(5));
    let mut render_interval = tokio::time::interval(Duration::from_millis(100));

    // Event loop
    loop {
        tokio::select! {
            Some(Ok(event)) = event_stream.next() => {
                match event {
                    Event::Key(key) => match key.code {
                        KeyCode::Char('q') | KeyCode::Esc => break,
                        KeyCode::Tab | KeyCode::Right => app.next_tab(),
                        KeyCode::Left => app.previous_tab(),
                        KeyCode::Char('r') => {
                            match poll_dashboard().await {
                                Ok(data) => {
                                    app.set_data(data);
                                    app.error = None;
                                }
                                Err(e) => app.set_error(e),
                            }
                            match poll_euphrates().await {
                                Ok(data) => app.set_euphrates(data),
                                Err(e) => app.set_euphrates_error(e),
                            }
                        }
                        _ => {}
                    },
                    Event::Mouse(_) => {}
                    _ => {}
                }
            }
            _ = poll_interval.tick() => {
                match poll_dashboard().await {
                    Ok(data) => app.set_data(data),
                    Err(e) => {
                        eprintln!("Poll error: {}", e);
                    }
                }
                match poll_euphrates().await {
                    Ok(data) => app.set_euphrates(data),
                    Err(e) => app.set_euphrates_error(e),
                }
            }
            _ = render_interval.tick() => {
                let _ = terminal.draw(|f| {
                    let area = f.area();
                    let buf = f.buffer_mut();
                    render(area, buf, &mut app, &theme);
                });
            }
        }
    }

    // Only reached via break on q/Esc

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    execute!(terminal.backend_mut(), DisableMouseCapture)?;
    terminal.show_cursor()?;

    Ok(())
}

fn render(area: Rect, buf: &mut Buffer, app: &mut App, theme: &Theme) {
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
        .style(Style::default().fg(theme.on_surface()))
        .highlight_style(Style::default().fg(theme.primary()));
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
        Some(TabType::Dashboard) => tabs::dashboard::render(content_area, buf, app, theme),
        Some(TabType::Network) => tabs::network::render(content_area, buf, app, theme),
        Some(TabType::Monitor) => tabs::monitor::render(content_area, buf, app, theme),
        Some(TabType::Sessions) => tabs::sessions::render(content_area, buf, app, theme),
        Some(TabType::Osint) => tabs::osint::render(content_area, buf, app, theme),
        None => {}
    }
}
