use crate::poller::{DashboardData, EuphratesData};

pub enum TabType {
    Dashboard,
    Network,
    Monitor,
    Sessions,
    Osint,
}

impl TabType {
    pub fn all() -> Vec<TabType> {
        vec![
            TabType::Dashboard,
            TabType::Network,
            TabType::Monitor,
            TabType::Sessions,
            TabType::Osint,
        ]
    }

    pub fn name(&self) -> &str {
        match self {
            TabType::Dashboard => "DASHBOARD",
            TabType::Network => "NETWORK",
            TabType::Monitor => "MONITOR",
            TabType::Sessions => "SESSIONS",
            TabType::Osint => "OSINT",
        }
    }
}

pub struct App {
    pub current_tab: usize,
    pub data: Option<DashboardData>,
    pub euphrates: Option<EuphratesData>,
    pub loading: bool,
    pub error: Option<String>,
    pub euphrates_error: Option<String>,
}

impl App {
    pub fn new() -> Self {
        Self {
            current_tab: 0,
            data: None,
            euphrates: None,
            loading: true,
            error: None,
            euphrates_error: None,
        }
    }

    pub fn next_tab(&mut self) {
        self.current_tab = (self.current_tab + 1) % TabType::all().len();
    }

    pub fn previous_tab(&mut self) {
        if self.current_tab == 0 {
            self.current_tab = TabType::all().len() - 1;
        } else {
            self.current_tab -= 1;
        }
    }

    pub fn set_data(&mut self, data: DashboardData) {
        self.data = Some(data);
        self.loading = false;
        self.error = None;
    }

    pub fn set_euphrates(&mut self, data: EuphratesData) {
        self.euphrates = Some(data);
        self.euphrates_error = None;
    }

    pub fn set_error(&mut self, err: String) {
        self.error = Some(err);
        self.loading = false;
    }

    pub fn set_euphrates_error(&mut self, err: String) {
        self.euphrates_error = Some(err);
    }
}
