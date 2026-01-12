#[derive(Debug)]
pub struct App {
    pub current_tab: usize,
    // later: vaults: Vec<VaultEntry>,
    //        config: Config,
    //        chat messages, etc.
}

impl Default for App {
    fn default() -> Self {
        Self { current_tab: 0 }
    }
}

pub const TABS: [&str; 3] = ["Chat", "Vaults", "Settings"];