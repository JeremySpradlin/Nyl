use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{prelude::*, widgets::*};
use std::io::{self, Stdout};

use crate::app::{App, TABS};  // ← adjust path

mod app;
mod ui;

fn main() -> Result<()> {
    let mut terminal = setup_terminal()?;
    let mut app = App::default();

    // ── Main loop ───────────────────────────────────────
    loop {
        terminal.draw(|frame| ui::draw(frame, &app))?;

        if let Event::Key(key) = event::read()? {
            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Right | KeyCode::Char('l') => {
                    app.current_tab = (app.current_tab + 1).min(TABS.len() - 1);
                }
                KeyCode::Left | KeyCode::Char('h') => {
                    app.current_tab = app.current_tab.saturating_sub(1);
                }
                KeyCode::Char(c) if c.is_ascii_digit() => {
                    if let Some(n) = c.to_digit(10) {
                        let idx = (n as usize).saturating_sub(1);
                        if idx < TABS.len() { app.current_tab = idx; }
                    }
                }
                _ => {}
            }
        }
    }

    restore_terminal()?;
    Ok(())
}

// Boilerplate ──────────────────────────────────────────────

fn setup_terminal() -> Result<Terminal<CrosstermBackend<Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let terminal = Terminal::new(backend)?;
    Ok(terminal)
}

fn restore_terminal() -> Result<()> {
    disable_raw_mode()?;
    execute!(io::stdout(), LeaveAlternateScreen)?;
    Ok(())
}