use tui_textarea::TextArea;

#[derive(Debug)]
pub struct App {
    pub current_tab: usize,
    pub messages: Vec<Message>,
    pub textarea: TextArea<'static>,
    pub input_mode: InputMode,
}

#[derive(Debug, PartialEq, Clone, Copy)]
pub enum InputMode {
    Normal,
    Editing,
}

#[derive(Debug, PartialEq, Clone)]
pub struct Message {
    pub sender: Sender,
    pub text: String,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Sender {
    User, 
    Assistant,
}

pub const TABS: [&str; 3] = ["Chat", "Vaults", "Settings"];

impl Default for App {
    fn default() -> Self {
        let mut textarea = TextArea::default();
        textarea.set_cursor_line_style(
            ratatui::style::Style::default().add_modifier(ratatui::style::Modifier::UNDERLINED)
        );
        textarea.set_block(
            ratatui::widgets::block::Block::default()
                .borders(ratatui::widgets::Borders::ALL)
                .title(" Type message (Esc → cancel, Enter → send) ")
        );

        Self {
            current_tab: 0,
            messages: vec![
                Message { sender: Sender::Assistant, text: "Welcome to Nyl!".to_string() },
                Message { sender: Sender::Assistant, text: "Press 'Esc' to navigate or quit...".to_string() },
            ],
            textarea,
            input_mode: InputMode::Editing,
        }
    }
}