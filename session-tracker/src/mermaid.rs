use crate::Session;
use std::collections::HashMap;

fn format_duration(seconds: u64) -> String {
    if seconds == 0 {
        "60m".to_string()
    } else {
        let mins = seconds / 60;
        if mins == 0 {
            format!("{}s", seconds)
        } else {
            format!("{}m", mins)
        }
    }
}

fn format_gantt_datetime(rfc3339: &str) -> String {
    rfc3339
        .get(0..16)
        .unwrap_or("unknown")
        .replace('T', " ")
}

pub fn generate_timeline(sessions: &[Session]) -> String {
    let mut sections: HashMap<String, Vec<&Session>> = HashMap::new();
    for s in sessions {
        sections
            .entry(s.agent.clone())
            .or_default()
            .push(s);
    }

    let mut lines = vec![
        "gantt".to_string(),
        "    title Agent Session Timeline".to_string(),
        "    dateFormat YYYY-MM-DD HH:mm".to_string(),
        "    axisFormat %m/%d %H:%M".to_string(),
    ];

    let mut sorted_sessions: Vec<&Session> = sessions.iter().collect();
    sorted_sessions.sort_by(|a, b| b.started_at.cmp(&a.started_at));
    let limited: Vec<&Session> = sorted_sessions.into_iter().take(20).collect();

    for agent in ["opencode", "hermes"] {
        let agent_sessions: Vec<&&Session> = limited
            .iter()
            .filter(|s| s.agent == agent)
            .collect();
        if agent_sessions.is_empty() {
            continue;
        }
        let section_name = match agent {
            "opencode" => "OpenCode",
            "hermes" => "Hermes",
            _ => agent,
        };
        lines.push(format!("    section {}", section_name));
        for s in agent_sessions {
            let status_tag = if s.status == "active" {
                ":active,"
            } else {
                ":done,"
            };
            let start = format_gantt_datetime(&s.started_at);
            let dur = format_duration(s.uptime_seconds);
            lines.push(format!("    {} {} {}, {}", s.id, status_tag, start, dur));
        }
    }

    lines.join("\n")
}

pub fn generate_tools(sessions: &[Session]) -> String {
    let mut totals: HashMap<String, u64> = HashMap::new();
    for s in sessions {
        if s.agent != "opencode" {
            continue;
        }
        for (tool, count) in &s.tools {
            *totals.entry(tool.clone()).or_insert(0) += count;
        }
    }

    let mut entries: Vec<(String, u64)> = totals.into_iter().collect();
    entries.sort_by(|a, b| b.1.cmp(&a.1));

    let mut lines = vec!["pie title Tool Usage (OpenCode)".to_string()];
    for (tool, count) in entries {
        lines.push(format!("    \"{}\" : {}", tool, count));
    }

    lines.join("\n")
}

pub fn generate_models(sessions: &[Session]) -> String {
    let mut counts: HashMap<String, u64> = HashMap::new();
    for s in sessions {
        *counts.entry(s.model.clone()).or_insert(0) += 1;
    }
    counts.retain(|k, v| !(k == "unknown" && *v == 0));

    let mut entries: Vec<(String, u64)> = counts.into_iter().collect();
    entries.sort_by(|a, b| b.1.cmp(&a.1));

    let mut lines = vec!["pie title Model Routing".to_string()];
    for (model, count) in entries {
        lines.push(format!("    \"{}\" : {}", model, count));
    }

    lines.join("\n")
}

pub fn render_svg(mermaid_text: &str) -> Result<String, String> {
    mermaid_rs_renderer::render(mermaid_text)
        .map_err(|e| format!("mermaid render error: {:?}", e))
}
