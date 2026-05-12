use serde::{Deserialize, Serialize};
use std::collections::HashMap;

mod hermes;
mod mermaid;
mod opencode;

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
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TrackerState {
    pub generated_at: String,
    pub sessions: Vec<Session>,
}

fn write_atomic(path: &str, content: &str) {
    let tmp = format!("{}.tmp", path);
    std::fs::write(&tmp, content).expect("write tmp file");
    std::fs::rename(&tmp, path).expect("rename to final");
}

fn main() {
    let mut sessions = opencode::read_sessions();
    sessions.extend(hermes::read_sessions());

    let state = TrackerState {
        generated_at: chrono::Utc::now().to_rfc3339(),
        sessions,
    };

    let json = serde_json::to_string_pretty(&state).expect("serialize state");
    write_atomic("/tmp/session-tracker.json", &json);

    if let Ok(svg) = mermaid::render_svg(&mermaid::generate_timeline(&state.sessions)) {
        write_atomic("/tmp/session-tracker-timeline.svg", &svg);
    }
    if let Ok(svg) = mermaid::render_svg(&mermaid::generate_tools(&state.sessions)) {
        write_atomic("/tmp/session-tracker-tools.svg", &svg);
    }
    if let Ok(svg) = mermaid::render_svg(&mermaid::generate_models(&state.sessions)) {
        write_atomic("/tmp/session-tracker-models.svg", &svg);
    }
}
