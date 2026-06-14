use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct VmInfo {
    pub name: String,
    pub state: String,
    pub vcpus: u32,
    pub memory_mb: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ContainerInfo {
    pub name: String,
    pub status: String,
    pub image: String,
    pub ports: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct ServiceInfo {
    pub name: String,
    #[serde(rename = "type")]
    pub service_type: String,
    pub status: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WgPeer {
    pub name: String,
    pub connected: bool,
    pub latest_handshake: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WgTunnel {
    pub name: String,
    pub status: String,
    pub ip: String,
    pub peers: Vec<WgPeer>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NftablesInfo {
    pub enabled: bool,
    pub rules_count: u32,
}

#[derive(Debug, Clone, Deserialize)]
pub struct WifiInfo {
    pub ssid: String,
    pub strength: u32,
    pub connected: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct EthernetInfo {
    pub ip: String,
    pub up: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct NetworkInfo {
    pub wg: Vec<WgTunnel>,
    pub nftables: NftablesInfo,
    pub wifi: WifiInfo,
    pub ethernet: EthernetInfo,
    pub dns: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct C2Framework {
    pub name: String,
    pub web_ui: String,
    pub status: String,
}

#[derive(Debug, Clone, Deserialize)]
pub struct TmuxSession {
    pub session: String,
    pub windows: u32,
    pub attached: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct DashboardData {
    pub vms: Vec<VmInfo>,
    pub containers: Vec<ContainerInfo>,
    pub services: Vec<ServiceInfo>,
    pub network: NetworkInfo,
    pub c2: Vec<C2Framework>,
    pub tmux: Vec<TmuxSession>,
}

pub fn poll_dashboard() -> Result<DashboardData, String> {
    let output = std::process::Command::new("/home/ForeverLX/Github/nightforge/dashboard-ctl/dashboard-ctl")
        .arg("poll")
        .output()
        .map_err(|e| format!("Failed to execute dashboard-ctl: {}", e))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("dashboard-ctl exited with error: {}", stderr));
    }

    let data: DashboardData = serde_json::from_slice(&output.stdout)
        .map_err(|e| format!("Failed to parse JSON: {}", e))?;

    Ok(data)
}

pub fn poll_dashboard_mock() -> DashboardData {
    DashboardData {
        vms: vec![],
        containers: vec![],
        services: vec![],
        network: NetworkInfo {
            wg: vec![],
            nftables: NftablesInfo { enabled: false, rules_count: 0 },
            wifi: WifiInfo { ssid: String::new(), strength: 0, connected: false },
            ethernet: EthernetInfo { ip: String::new(), up: false },
            dns: String::new(),
        },
        c2: vec![],
        tmux: vec![],
    }
}

// --- Euphrates API types ---

#[derive(Debug, Clone, serde::Deserialize)]
pub struct CveItem {
    pub id: String,
    pub published_at: String,
    pub description: String,
    pub cvss_score: f64,
    pub vulnerability_class: String,
    pub rootless_exploitability: String,
    pub source: String,
}

#[derive(Debug, Clone, serde::Deserialize)]
pub struct EuphratesData {
    pub cves: Vec<CveItem>,
    pub feeds: Vec<serde_json::Value>,
}

pub fn poll_euphrates() -> Result<EuphratesData, String> {
    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
        .map_err(|e| format!("euphrates client: {}", e))?;

    let cves: Vec<CveItem> = client
        .get("http://localhost:8480/api/cves")
        .send()
        .map_err(|e| format!("euphrates cves: {}", e))?
        .json()
        .map_err(|e| format!("euphrates cves json: {}", e))?;

    let feeds: Vec<serde_json::Value> = client
        .get("http://localhost:8480/api/feeds")
        .send()
        .map_err(|e| format!("euphrates feeds: {}", e))?
        .json()
        .map_err(|e| format!("euphrates feeds json: {}", e))?;

    Ok(EuphratesData { cves, feeds })
}
