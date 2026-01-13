use ratatui::{
    prelude::*,
    widgets::{Block, Borders, List, ListItem, Paragraph, Tabs},
};
// use tui_textarea::TextArea;

use crate::app::{App, TABS};

pub fn draw(frame: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // tabs
            Constraint::Min(0),    // content
        ])
        .split(frame.area());

    // ── Tabs ───────────────────────────────────────────────
    let tabs = Tabs::new(TABS.iter().cloned().map(Line::from))
        .block(Block::default().title(" Nyl ").borders(Borders::ALL))
        .select(app.current_tab)
        .style(Style::default().fg(Color::White))
        .highlight_style(Style::default().fg(Color::Yellow).bold());

    frame.render_widget(tabs, chunks[0]);

    // ── Content ────────────────────────────────────────────
    match app.current_tab {
        0 => {
            let inner_chunks = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Min(0),     // chat history
                    Constraint::Length(4),  // input field
                ])
                .split(chunks[1]);

            // Message history (newest at bottom)
            let items: Vec<ListItem> = app.messages
                .iter()
                .rev()
                .map(|msg| ListItem::new(msg.as_str()))
                .collect();

            let chat_list = List::new(items)
                .block(Block::default().title(" Chat ").borders(Borders::ALL));

            frame.render_widget(chat_list, inner_chunks[0]);

            // Input area - render TextArea directly (no .widget() anymore)
            frame.render_widget(app.textarea.widget(), inner_chunks[1]);
        }

        1 => {
            frame.render_widget(
                Paragraph::new("Vault management coming soon..."),
                chunks[1],
            );
        }

        2 => {
            frame.render_widget(
                Paragraph::new("Settings & about screen"),
                chunks[1],
            );
        }

        _ => {
            frame.render_widget(Paragraph::new("???"), chunks[1]);
        }
    }
}