use serde::{Deserialize, Serialize};
use std::collections::HashMap;

mod hermes;
mod opencode;

fn main() {
    let machine = get_machine();
    let mut sessions = opencode::read_sessions(&machine);
    sessions.extend(hermes::read_sessions(&machine));

    let state = TrackerState {
        generated_at: chrono::Utc::now().to_rfc3339(),
        sessions,
        machine,
    };

    let json = serde_json::to_string_pretty(&state).expect("serialize state");
    write_atomic("/tmp/session-tracker.json", &json);
}

fn get_machine() -> String {
    std::process::Command::new("hostname")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "unknown".to_string())
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Session {
    pub id: String,
    pub agent: String,
    pub status: String,
    pub started_at: String,
    pub uptime_seconds: u64,
    pub total_calls: u64,
    pub tokens_saved: u64,
    pub cost_saved: f64,
    pub model: String,
    pub tools: HashMap<String, u64>,
    pub machine: String,
    pub workdir: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TrackerState {
    pub generated_at: String,
    pub sessions: Vec<Session>,
    pub machine: String,
}

fn write_atomic(path: &str, content: &str) {
    let tmp = format!("{}.tmp", path);
    std::fs::write(&tmp, content).expect("write tmp file");
    std::fs::rename(&tmp, path).expect("rename to final");
}


