use crate::Session;
use chrono::{NaiveDate, NaiveDateTime, TimeZone, Utc};
use std::collections::HashMap;
use std::path::Path;
use walkdir::WalkDir;

fn sessions_dir() -> String {
    format!(
        "{}/.hermes/sessions",
        std::env::var("HOME").unwrap_or_else(|_| "/root".into())
    )
}

fn parse_timestamp_from_filename(fname: &str) -> Option<chrono::NaiveDateTime> {
    let fname = fname.trim_end_matches(".json");
    let parts: Vec<&str> = fname.split('_').collect();
    if parts.len() < 4 {
        return None;
    }
    let date_part = parts.get(1)?;
    let time_part = parts.get(2)?;
    if date_part.len() != 8 || time_part.len() != 6 {
        return None;
    }
    let year: i32 = date_part.get(0..4)?.parse().ok()?;
    let month: u32 = date_part.get(4..6)?.parse().ok()?;
    let day: u32 = date_part.get(6..8)?.parse().ok()?;
    let hour: u32 = time_part.get(0..2)?.parse().ok()?;
    let minute: u32 = time_part.get(2..4)?.parse().ok()?;
    let second: u32 = time_part.get(4..6)?.parse().ok()?;
    NaiveDate::from_ymd_opt(year, month, day)
        .and_then(|d| d.and_hms_opt(hour, minute, second))
}

fn read_model_from_config() -> String {
    let config_path = format!(
        "{}/.hermes/config.yaml",
        std::env::var("HOME").unwrap_or_else(|_| "/root".into())
    );
    let content = match std::fs::read_to_string(&config_path) {
        Ok(c) => c,
        Err(_) => return "unknown".to_string(),
    };
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("default:") {
            let model = trimmed.trim_start_matches("default:").trim();
            if !model.is_empty() {
                return model.to_string();
            }
        }
    }
    "unknown".to_string()
}

pub fn read_sessions() -> Vec<Session> {
    let dir = sessions_dir();
    if !Path::new(&dir).exists() {
        return Vec::new();
    }

    let model = read_model_from_config();

    let mut entries: Vec<(String, NaiveDateTime, std::path::PathBuf)> = Vec::new();

    for entry in WalkDir::new(&dir)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let fname = entry.file_name().to_string_lossy().to_string();
        if !fname.starts_with("session_") || !fname.ends_with(".json") {
            continue;
        }
        let ts = match parse_timestamp_from_filename(&fname) {
            Some(t) => t,
            None => continue,
        };
        let id = fname.trim_end_matches(".json").to_string();
        entries.push((id, ts, entry.path().to_path_buf()));
    }

    entries.sort_by(|a, b| b.1.cmp(&a.1));
    let most_recent_path = entries.first().map(|e| e.2.clone());

    let mut sessions = Vec::new();
    for (id, ts, path) in &entries {
        let started_at = Utc.from_utc_datetime(ts).to_rfc3339();
        let is_most_recent = most_recent_path
            .as_ref()
            .map(|p| p == path)
            .unwrap_or(false);

        let status = if is_most_recent {
            let meta = std::fs::metadata(path);
            match meta {
                Ok(m) => {
                    if let Ok(modified) = m.modified() {
                        let elapsed = modified
                            .elapsed()
                            .unwrap_or(std::time::Duration::from_secs(u64::MAX));
                        if elapsed.as_secs() < 300 {
                            "active"
                        } else {
                            "ended"
                        }
                    } else {
                        "ended"
                    }
                }
                Err(_) => "ended",
            }
        } else {
            "ended"
        };

        sessions.push(Session {
            id: id.clone(),
            agent: "hermes".to_string(),
            status: status.to_string(),
            started_at,
            uptime_seconds: 0,
            total_calls: 0,
            tokens_saved: 0,
            cost_saved: 0.0,
            model: model.clone(),
            tools: HashMap::new(),
        });
    }

    sessions
}
