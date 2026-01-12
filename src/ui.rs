use ratatui::{
    prelude::*,
    widgets::{Block, Borders, Paragraph, Tabs},
};

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

    // ── Content placeholder ───────────────────────────────
    let content = match app.current_tab {
        0 => Paragraph::new("Chat will live here... (coming soon)"),
        1 => Paragraph::new("Vault management coming next!"),
        2 => Paragraph::new("Settings & about screen"),
        _ => Paragraph::new("???"),
    };

    frame.render_widget(content, chunks[1]);
}