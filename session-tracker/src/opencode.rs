use crate::Session;
use chrono::{TimeZone, Utc};
use serde::Deserialize;
use std::collections::HashMap;
use std::path::Path;
use walkdir::WalkDir;

#[derive(Deserialize, Debug)]
struct StatsFile {
    session_start: i64,
    uptime_ms: u64,
    total_calls: u64,
    tokens_saved: u64,
    dollars_saved_session: f64,
    by_tool: Option<HashMap<String, ToolStats>>,
}

#[derive(Deserialize, Debug)]
struct ToolStats {
    calls: u64,
}

fn sessions_dir() -> String {
    format!(
        "{}/.config/opencode/context-mode/sessions",
        dirs_home()
    )
}

fn dirs_home() -> String {
    std::env::var("HOME").unwrap_or_else(|_| "/root".into())
}

fn is_recently_active(path: &Path, threshold_secs: u64) -> bool {
    let metadata = match std::fs::metadata(path) {
        Ok(m) => m,
        Err(_) => return false,
    };
    let modified = match metadata.modified() {
        Ok(t) => t,
        Err(_) => return false,
    };
    let elapsed = modified.elapsed().unwrap_or(std::time::Duration::from_secs(u64::MAX));
    elapsed.as_secs() < threshold_secs
}

pub fn read_sessions() -> Vec<Session> {
    let dir = sessions_dir();
    if !Path::new(&dir).exists() {
        return Vec::new();
    }

    let mut sessions = Vec::new();

    for entry in WalkDir::new(&dir)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let fname = entry.file_name().to_string_lossy().to_string();
        if !fname.starts_with("stats-pid-") || !fname.ends_with(".json") {
            continue;
        }

        let path = entry.path();
        let content = match std::fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => continue,
        };

        let stats: StatsFile = match serde_json::from_str(&content) {
            Ok(s) => s,
            Err(_) => continue,
        };

        let id = fname.trim_end_matches(".json").to_string();
        let started = Utc.timestamp_millis_opt(stats.session_start);
        let started_at = started
            .single()
            .map(|dt| dt.to_rfc3339())
            .unwrap_or_else(|| "unknown".to_string());

        let tools: HashMap<String, u64> = stats
            .by_tool
            .unwrap_or_default()
            .into_iter()
            .map(|(k, v)| (k, v.calls))
            .collect();

        let status = if is_recently_active(path, 60) {
            "active".to_string()
        } else {
            "ended".to_string()
        };

        sessions.push(Session {
            id,
            agent: "opencode".to_string(),
            status,
            started_at,
            uptime_seconds: stats.uptime_ms / 1000,
            total_calls: stats.total_calls,
            tokens_saved: stats.tokens_saved,
            cost_saved: stats.dollars_saved_session,
            model: "unknown".to_string(),
            tools,
        });
    }

    sessions
}
