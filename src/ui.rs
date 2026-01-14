use ratatui::{
    prelude::*,
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Tabs},
};

use crate::app::{App, Sender, TABS};

pub fn draw(frame: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // tabs
            Constraint::Min(0),    // content
        ])
        .split(frame.area());

    // ── Tabs ─────────────────────────────────────────────
    let tabs = Tabs::new(TABS.iter().copied().map(Line::from))
        .block(Block::default().title(" Nyl ").borders(Borders::ALL))
        .select(app.current_tab)
        .highlight_style(Style::default().fg(Color::Yellow).bold());

    frame.render_widget(tabs, chunks[0]);

    // ── Content ──────────────────────────────────────────
    match app.current_tab {
        0 => draw_chat_tab(frame, app, chunks[1]),
        1 => frame.render_widget(Paragraph::new("Vault (coming soon)"), chunks[1]),
        2 => frame.render_widget(Paragraph::new("Settings / About"), chunks[1]),
        _ => {}
    }
}

fn draw_chat_tab(frame: &mut Frame, app: &App, area: Rect) {
    let layout = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Min(0),    // chat history
            Constraint::Length(4), // input
        ])
        .split(area);

    // ── Chat history ─────────────────────────────────────
    let chat_block = Block::default()
        .borders(Borders::ALL)
        .title(" Chat ");

    frame.render_widget(chat_block.clone(), layout[0]);
    let chat_area = chat_block.inner(layout[0]);

    let items: Vec<ListItem> = app
        .messages
        .iter()
        .map(|msg| ListItem::new(Text::from(format_message(msg.sender, &msg.text))))
        .collect();

    let list = List::new(items);

    let mut state = ListState::default();
    if !app.messages.is_empty() {
        state.select(Some(app.messages.len() - 1)); // auto-scroll to bottom
    }

    frame.render_stateful_widget(list, chat_area, &mut state);

    // ── Input ────────────────────────────────────────────
    frame.render_widget(&app.textarea, layout[1]);
}

fn format_message(sender: Sender, text: &str) -> Vec<Line<'static>> {
    let (label, color) = match sender {
        Sender::User => ("You", Color::Green),
        Sender::Assistant => ("Nyl", Color::Cyan),
    };

    let mut lines = Vec::new();

    lines.push(Line::from(vec![
        Span::styled(format!("{label}: "), Style::default().fg(color).bold()),
        Span::raw(text.to_string()),
    ]));

    lines.push(Line::from("")); // blank line between messages
    lines
}
