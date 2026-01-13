use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    // prelude::*,
    widgets::*,
    backend::CrosstermBackend,
    Terminal,
};
use std::io::{self, Stdout};

use crate::app::{App, InputMode, TABS};
use tui_textarea::{TextArea, Input};   // ← important: add this

mod app;
mod ui;

fn main() -> Result<()> {
    let mut terminal = setup_terminal()?;
    let mut app = App::default();

    loop {
        terminal.draw(|frame| ui::draw(frame, &app))?;

        if let Event::Key(key) = event::read()? {
            if app.input_mode == InputMode::Editing {
                match key.code {
                    KeyCode::Esc => {
                        app.input_mode = InputMode::Normal;
                    }
                    KeyCode::Enter => {
                        let message = app.textarea.lines().join("\n").trim().to_string();
                        if !message.is_empty() {
                            app.messages.push(message);
                        }
                        app.textarea = TextArea::default();
                        app.textarea.set_block(
                            ratatui::widgets::block::Block::default()
                                .borders(ratatui::widgets::Borders::ALL)
                                .title(" Type message (Esc → cancel, Enter → send) ")
                        );
                        app.input_mode = InputMode::Normal;
                    }
                    _ => {
                        // tui-textarea expects its own Input type
                        let _ = app.textarea.input(Input::from(KeyEvent::from(key)));
                    }
                }
            } else {
                // Normal mode
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    KeyCode::Char('i') => {
                        app.input_mode = InputMode::Editing;
                    }
                    KeyCode::Right | KeyCode::Char('l') => {
                        app.current_tab = (app.current_tab + 1).min(TABS.len() - 1);
                    }
                    KeyCode::Left | KeyCode::Char('h') => {
                        app.current_tab = app.current_tab.saturating_sub(1);
                    }
                    KeyCode::Char(c) if c.is_ascii_digit() => {
                        if let Some(n) = c.to_digit(10) {
                            let idx = (n as usize).saturating_sub(1);
                            if idx < TABS.len() {
                                app.current_tab = idx;
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    restore_terminal()?;
    Ok(())
}

fn setup_terminal() -> Result<Terminal<CrosstermBackend<Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    Ok(Terminal::new(backend)?)
}

fn restore_terminal() -> Result<()> {
    disable_raw_mode()?;
    execute!(io::stdout(), LeaveAlternateScreen)?;
    Ok(())
}