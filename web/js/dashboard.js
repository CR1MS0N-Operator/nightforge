/* Nightforge Dashboard — Main SPA Logic */

// ---- State ----
let state = { services: [], tasks: [], ports: [], health: null, analysis: [], alerts: [], layers: [] };
let charts = {};
let sse = null;

// ---- Init ----
document.addEventListener("DOMContentLoaded", () => {
  setupNav();
  setupKeyboardNav();
  fetchAll();
  connectSSE();
  setupLogs();
  setupLayerTabs();
});

// ---- Navigation ----
function setupNav() {
  document.querySelectorAll("#navList .nav-link").forEach(link => {
    link.addEventListener("click", e => {
      e.preventDefault();
      const section = link.dataset.section;
      switchSection(section);
      if (section === "logs" && document.getElementById("logFileSelect").options.length <= 1) {
        fetchLogFiles();
      }
    });
  });
}

function switchSection(name) {
  document.querySelectorAll(".section-content").forEach(s => s.classList.add("d-none"));
  const target = document.getElementById("section-" + name);
  if (target) target.classList.remove("d-none");
  document.querySelectorAll("#navList .nav-link").forEach(l => l.classList.remove("active"));
  const link = document.querySelector(`[data-section="${name}"]`);
  if (link) link.classList.add("active");
}

// ---- Keyboard Navigation ----
function setupKeyboardNav() {
  const sections = ["overview", "tasks", "ports", "analysis", "logs", "layers", "api-usage"];
  let currentIndex = 0;

  document.addEventListener("keydown", (e) => {
    // Don't trigger if user is typing in an input
    if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA" || e.target.tagName === "SELECT") {
      return;
    }

    switch (e.key) {
      case "1": case "2": case "3": case "4": case "5": case "6": case "7":
        // Alt+1-7 to jump to sections
        if (e.altKey) {
          e.preventDefault();
          const idx = parseInt(e.key) - 1;
          if (idx < sections.length) {
            currentIndex = idx;
            switchSection(sections[currentIndex]);
          }
        }
        break;
      case "j": // Next section
      case "ArrowDown":
        if (e.ctrlKey) {
          e.preventDefault();
          currentIndex = (currentIndex + 1) % sections.length;
          switchSection(sections[currentIndex]);
        }
        break;
      case "k": // Previous section
      case "ArrowUp":
        if (e.ctrlKey) {
          e.preventDefault();
          currentIndex = (currentIndex - 1 + sections.length) % sections.length;
          switchSection(sections[currentIndex]);
        }
        break;
      case "r": // Refresh
        if (e.ctrlKey) {
          e.preventDefault();
          fetchAll();
        }
        break;
      case "Escape": // Close any open modal or return to overview
        switchSection("overview");
        currentIndex = 0;
        break;
    }
  });
}

// ---- Data Fetching ----
async function fetchAll() {
  try {
    const [svc, tsk, prt, hlth, anl, alrt, lyrs] = await Promise.all([
      fetch("/api/v1/services").then(r => r.json()).catch(() => ({})),
      fetch("/api/v1/tasks").then(r => r.json()).catch(() => ({})),
      fetch("/api/v1/ports").then(r => r.json()).catch(() => ({})),
      fetch("/api/v1/health").then(r => r.json()).catch(() => null),
      fetch("/api/v1/analysis").then(r => r.json()).catch(() => ({})),
      fetch("/api/v1/alerts").then(r => r.json()).catch(() => ({})),
      fetch("/api/v1/layers").then(r => r.json()).catch(() => ({})),
    ]);

    state.services = Array.isArray(svc) ? svc : (svc.services || []);
    state.tasks    = Array.isArray(tsk) ? tsk : (tsk.tasks || []);
    state.ports    = Array.isArray(prt) ? prt : (prt.ports || []);
    state.health   = hlth ? (hlth.health || hlth) : null;
    state.analysis = Array.isArray(anl) ? anl : (anl.analysis || []);
    state.alerts   = Array.isArray(alrt) ? alrt : (alrt.alerts || []);
    state.layers   = Array.isArray(lyrs) ? lyrs : (lyrs.layers || []);

    renderAll();
  } catch (err) {
    console.error("fetchAll:", err);
  }
}

function renderAll() {
  renderAlerts();
  renderOverview();
  renderTasks();
  renderPorts();
  renderAnalysis();
  renderLayers();
  renderApiUsage();
}

// ---- SSE ----
function connectSSE() {
  if (sse) sse.close();
  sse = new EventSource("/api/v1/events");

  sse.onopen = () => setConnection(true);
  sse.onerror = () => {
    setConnection(false);
    sse.close();
    setTimeout(connectSSE, 5000);
  };

  sse.addEventListener("update", e => {
    try {
      const data = JSON.parse(e.data);
      if (data.services) state.services = data.services;
      if (data.tasks)    state.tasks    = data.tasks;
      if (data.ports)    state.ports    = data.ports;
      if (data.health)   state.health   = data.health;
      if (data.analysis) state.analysis = data.analysis;
      if (data.alerts)   state.alerts   = data.alerts;
      if (data.layers)   state.layers   = data.layers;
      renderAll();
    } catch (err) {
      console.error("SSE parse:", err);
    }
  });

  sse.onmessage = e => {
    try {
      const data = JSON.parse(e.data);
      if (data.type === "update" || data.services || data.tasks || data.ports || data.health) {
        if (data.services) state.services = data.services;
        if (data.tasks)    state.tasks    = data.tasks;
        if (data.ports)    state.ports    = data.ports;
        if (data.health)   state.health   = data.health;
        if (data.analysis) state.analysis = data.analysis;
        if (data.alerts)   state.alerts   = data.alerts;
        if (data.layers)   state.layers   = data.layers;
        renderAll();
      }
    } catch (_) { /* ignore */ }
  };
}

function setConnection(live) {
  const dot = document.getElementById("connectionDot");
  const label = document.getElementById("connectionLabel");
  if (dot) dot.className = "status-dot " + (live ? "live" : "dead");
  if (label) label.textContent = live ? "live" : "disconnected";
}

// ---- Alerts ----
function renderAlerts() {
  const banner = document.getElementById("alertBanner");
  if (!banner) return;
  if (!state.alerts || state.alerts.length === 0) {
    banner.classList.add("d-none");
    return;
  }
  banner.classList.remove("d-none");
  const critical = state.alerts.filter(a => a.severity === "critical");
  const warns = state.alerts.filter(a => a.severity === "warning");
  const badge = critical.length > 0
    ? `<span class="badge bg-danger me-2">${critical.length} critical</span>`
    : `<span class="badge bg-warning text-dark me-2">${warns.length} warning</span>`;
  banner.innerHTML = `<div class="alert alert-${critical.length > 0 ? 'danger' : 'warning'} d-flex align-items-center mb-0 py-2">
    ${badge}
    <span class="small">${state.alerts.map(a => esc(a.message)).join("; ")}</span>
    <button type="button" class="btn-close ms-auto" onclick="document.getElementById('alertBanner').classList.add('d-none')"></button>
  </div>`;
}

// ---- Overview ----
function renderOverview() {
  renderServiceCards();
  renderBonsaiStatus();
  renderCpuLoad();
  renderGpuMem();
  renderCharts();
  renderOverviewTaskTable();
}

function renderServiceCards() {
  const container = document.getElementById("serviceCards");
  if (!container) return;
  if (!state.services.length) {
    container.innerHTML = '<div class="col-12 text-muted">No services registered.</div>';
    return;
  }
  container.innerHTML = state.services.map(s => {
    const up = s.status === "UP";
    return `<div class="col-xl-3 col-lg-4 col-md-6">
      <div class="card h-100">
        <div class="card-body">
          <h6 class="fw-bold">${esc(s.name)}</h6>
          <div class="d-flex justify-content-between align-items-center">
            <small class="text-muted">Port ${esc(String(s.port))}</small>
            <span class="service-pill ${up ? "badge-up" : "badge-down"}">${up ? "UP" : "DOWN"}</span>
          </div>
        </div>
      </div>
    </div>`;
  }).join("");
}

function renderBonsaiStatus() {
  const el = document.getElementById("bonsaiStatus");
  if (!el) return;
  const bonsai = state.services.find(s => s.name && s.name.toLowerCase().includes("bonsai"));
  if (bonsai) {
    const up = bonsai.status === "UP";
    el.innerHTML = `<span class="fw-bold">${esc(bonsai.name)}</span>
      <span class="service-pill ms-2 ${up ? "badge-up" : "badge-down"}">${up ? "UP" : "DOWN"}</span>
      <br><small class="text-muted">Port ${esc(String(bonsai.port))}</small>`;
  } else {
    el.innerHTML = '<span class="text-muted">No Bonsai service found.</span>';
  }
}

function renderCpuLoad() {
  const el = document.getElementById("cpuLoad");
  if (!el || !state.health) return;
  const load = state.health.load || [];
  el.innerHTML = `<div class="fs-4 fw-bold">${load.map(n => n.toFixed(2)).join(" / ")}</div>
    <small class="text-muted">1 min / 5 min / 15 min</small>`;
}

function renderGpuMem() {
  const el = document.getElementById("gpuMem");
  if (!el || !state.health) return;
  const used = state.health.gpu_mem || 0;
  const total = state.health.gpu_total || 0;
  const pct = total ? ((used / total) * 100).toFixed(1) : "?";
  el.innerHTML = `<div class="fs-4 fw-bold">${pct}%</div>
    <small class="text-muted">${used} MB / ${total} MB</small>`;
}

function renderOverviewTaskTable() {
  const tbody = document.querySelector("#overviewTaskTable tbody");
  if (!tbody) return;
  if (!state.tasks.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-muted">No tasks.</td></tr>';
    return;
  }
  tbody.innerHTML = state.tasks.slice(0, 5).map(t => taskRow(t)).join("");
}

// ---- Tasks ----
function renderTasks() {
  const tbody = document.getElementById("taskTableBody");
  if (!tbody) return;
  if (!state.tasks.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-muted">No tasks.</td></tr>';
    return;
  }
  tbody.innerHTML = state.tasks.map(t => taskRow(t)).join("");
}

function taskRow(t) {
  const status = t.status || "";
  let cls = "badge-ok";
  if (/err|fail|down/i.test(status)) cls = "badge-err";
  else if (/warn/i.test(status)) cls = "badge-warn";
  return `<tr>
    <td>${esc(t.name)}</td>
    <td><span class="service-pill ${cls}">${esc(status)}</span></td>
    <td><small class="text-muted">${esc(t.last_run || "")}</small></td>
  </tr>`;
}

// ---- Ports ----
function renderPorts() {
  const tbody = document.getElementById("portTableBody");
  if (!tbody) return;
  if (!state.ports.length) {
    tbody.innerHTML = '<tr><td colspan="3" class="text-muted">No ports.</td></tr>';
    return;
  }
  tbody.innerHTML = state.ports.map(p => `<tr>
    <td><code>${esc(String(p.port))}</code></td>
    <td>${esc(p.service || "")}</td>
    <td>${esc(p.process || "")}</td>
  </tr>`).join("");
}

// ---- Analysis ----
function renderAnalysis() {
  const container = document.getElementById("analysisCards");
  if (!container) return;
  if (!state.analysis.length) {
    container.innerHTML = '<div class="col-12 text-muted">No analysis available.</div>';
    return;
  }
  container.innerHTML = state.analysis.map(a => `<div class="col-lg-6 mb-3">
    <div class="card h-100">
      <div class="card-header">${esc(a.source || "analysis")}</div>
      <div class="card-body"><p class="mb-0" style="white-space:pre-wrap">${esc(a.text || "")}</p></div>
    </div>
  </div>`).join("");
}

// ---- Logs ----
function setupLogs() {
  const refreshBtn = document.getElementById("logRefreshBtn");
  const select = document.getElementById("logFileSelect");
  if (refreshBtn) refreshBtn.addEventListener("click", loadLogContent);
  if (select) select.addEventListener("change", loadLogContent);
}

async function fetchLogFiles() {
  const select = document.getElementById("logFileSelect");
  try {
    const res = await fetch("/api/v1/logs");
    const data = await res.json();
    // data.files is array of {name, path}; also fallback to flat array
    const files = data.files || data || [];
    select.innerHTML = '<option value="">-- select log --</option>' +
      files.map(f => `<option value="${esc(f.name || f)}">${esc(f.name || f)}</option>`).join("");
  } catch (err) {
    console.error("fetchLogFiles:", err);
  }
}

async function loadLogContent() {
  const select = document.getElementById("logFileSelect");
  const pre = document.getElementById("logContent");
  if (!select || !pre) return;
  const file = select.value;
  if (!file) { pre.textContent = "Select a log file."; return; }
  pre.textContent = "Loading...";
  try {
    const res = await fetch("/api/v1/logs?file=" + encodeURIComponent(file));
    const data = await res.json();
    pre.textContent = data.lines ? data.lines.join("\n") : (data.content || JSON.stringify(data, null, 2));
  } catch (err) {
    pre.textContent = "Failed to load log: " + err.message;
  }
}

// ---- Layers ----
function setupLayerTabs() {
  document.querySelectorAll("[data-layer-tab]").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll("[data-layer-tab]").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      loadLayerDetail(btn.dataset.layerTab);
    });
  });
}

async function loadLayerDetail(tab) {
  const content = document.getElementById("layerDetailContent");
  if (!content) return;
  content.innerHTML = '<p class="text-muted">Loading...</p>';
  let endpoint, label;
  switch (tab) {
    case "l4": endpoint = "/api/v1/layers/l4/failures"; label = "Failures"; break;
    case "l5": endpoint = "/api/v1/layers/l5/proposals"; label = "Proposals"; break;
    case "l6": endpoint = "/api/v1/layers/l6/gates"; label = "Gates"; break;
    case "l7": endpoint = "/api/v1/layers/l7/snapshots"; label = "Snapshots"; break;
    default: content.innerHTML = '<p class="text-muted">Unknown tab.</p>'; return;
  }
  try {
    const res = await fetch(endpoint);
    const data = await res.json();
    const items = data.failures || data.proposals || data.gates || data.snapshots || [];
    if (!items.length) {
      content.innerHTML = `<p class="text-muted">No ${label.toLowerCase()} found.</p>`;
      return;
    }
    content.innerHTML = renderLayerDetailTable(tab, items);
  } catch (err) {
    content.innerHTML = `<p class="text-danger">Failed to load: ${esc(err.message)}</p>`;
  }
}

function renderLayerDetailTable(tab, items) {
  switch (tab) {
    case "l4":
      return `<div class="table-responsive"><table class="table table-striped mb-0">
        <thead><tr><th>ID</th><th>Category</th><th>Count</th><th>Summary</th></tr></thead>
        <tbody>${items.map(i => `<tr><td>${esc(i.id || "")}</td><td>${esc(i.category || "")}</td><td>${esc(String(i.count || 0))}</td><td>${esc(i.summary || "")}</td></tr>`).join("")}</tbody>
      </table></div>`;
    case "l5":
      return `<div class="table-responsive"><table class="table table-striped mb-0">
        <thead><tr><th>ID</th><th>Title</th><th>Impact</th><th>Effort</th><th>Status</th></tr></thead>
        <tbody>${items.map(i => `<tr><td>${esc(i.id || "")}</td><td>${esc(i.title || "")}</td><td>${esc(String(i.impact_score || 0))}</td><td>${esc(String(i.effort_score || 0))}</td><td>${esc(i.status || "")}</td></tr>`).join("")}</tbody>
      </table></div>`;
    case "l6":
      return `<div class="table-responsive"><table class="table table-striped mb-0">
        <thead><tr><th>Name</th><th>Status</th><th>Duration</th><th>Error</th></tr></thead>
        <tbody>${items.map(i => `<tr><td>${esc(i.name || "")}</td><td><span class="service-pill ${i.status === "PASS" ? "badge-up" : i.status === "FAIL" ? "badge-down" : "badge-warn"}">${esc(i.status || "")}</span></td><td>${i.duration ? i.duration.toFixed(3) + "s" : "—"}</td><td>${esc(i.error || "—")}</td></tr>`).join("")}</tbody>
      </table></div>`;
    case "l7":
      return `<div class="table-responsive"><table class="table table-striped mb-0">
        <thead><tr><th>ID</th><th>Timestamp</th><th>Size</th></tr></thead>
        <tbody>${items.map(i => `<tr><td>${esc(i.id || "")}</td><td>${esc(i.timestamp || "")}</td><td>${i.size ? formatBytes(i.size) : "—"}</td></tr>`).join("")}</tbody>
      </table></div>`;
    default:
      return `<pre>${esc(JSON.stringify(items, null, 2))}</pre>`;
  }
}

function formatBytes(bytes) {
  if (!bytes || bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
}

function renderLayers() {
  const container = document.getElementById("layerCards");
  if (!container) return;
  if (!state.layers.length) {
    container.innerHTML = '<div class="col-12 text-muted">No layers data.</div>';
    return;
  }
  container.innerHTML = state.layers.map(l => {
    const statusMap = {
      "implemented":     { cls: "bg-success", icon: "bi-check-circle-fill" },
      "available":       { cls: "bg-warning text-dark", icon: "bi-exclamation-triangle-fill" },
      "not_implemented": { cls: "bg-secondary", icon: "bi-x-circle-fill" },
    };
    const s = statusMap[l.status] || statusMap["not_implemented"];
    return `<div class="col-xl-3 col-lg-4 col-md-6">
      <div class="card h-100">
        <div class="card-body">
          <div class="d-flex justify-content-between align-items-start mb-2">
            <span class="badge ${esc(s.cls)}"><i class="bi ${esc(s.icon)} me-1"></i>${esc(l.status)}</span>
            <small class="text-muted fw-bold">L${l.id}</small>
          </div>
          <h6 class="fw-bold mb-1">${esc(l.name)}</h6>
          <p class="small text-muted mb-0">${esc(l.description || "")}</p>
          ${l.last_run ? `<small class="text-muted">Last run: ${esc(l.last_run)}</small>` : ""}
        </div>
      </div>
    </div>`;
  }).join("");
}

// ---- API Usage ----
function renderApiUsage() {
  const tbody = document.getElementById("apiUsageBody");
  if (!tbody) return;
  // Fetch usage data fresh
  fetch("/api/v1/usage").then(r => r.json()).then(data => {
    const records = data.records || [];
    if (!records.length) {
      tbody.innerHTML = '<tr><td colspan="7" class="text-muted">No usage data yet.</td></tr>';
      return;
    }
    tbody.innerHTML = records.map(r => `<tr>
      <td><strong>${esc(r.provider)}</strong></td>
      <td>${esc(r.model)}</td>
      <td>${r.tokens_in ? r.tokens_in.toLocaleString() : "—"}</td>
      <td>${r.tokens_out ? r.tokens_out.toLocaleString() : "—"}</td>
      <td>${r.cost != null ? "$" + r.cost.toFixed(4) : "—"}</td>
      <td>${r.request_count ? r.request_count.toLocaleString() : "—"}</td>
      <td><small class="text-muted">${esc(r.period)}</small></td>
    </tr>`).join("");

    // Token charts
    renderUsageCharts(records);
  }).catch(() => {
    tbody.innerHTML = '<tr><td colspan="7" class="text-muted">Failed to load usage data.</td></tr>';
  });
}

function renderUsageCharts(records) {
  // Aggregate by provider
  const byProvider = {};
  records.forEach(r => {
    if (!byProvider[r.provider]) byProvider[r.provider] = { tokensIn: 0, tokensOut: 0, cost: 0 };
    byProvider[r.provider].tokensIn += r.tokens_in || 0;
    byProvider[r.provider].tokensOut += r.tokens_out || 0;
    byProvider[r.provider].cost += r.cost || 0;
  });

  const providers = Object.keys(byProvider);
  if (providers.length === 0) return;

  const colors = ["#58a6ff", "#3fb950", "#f0883e", "#bc8cff", "#f85149", "#db6d28", "#e3b341"];

  // Doughnut: tokens per provider
  const tokenCanvas = document.getElementById("chartUsageTokens");
  if (tokenCanvas) {
    if (charts["chartUsageTokens"]) charts["chartUsageTokens"].destroy();
    const ctx = tokenCanvas.getContext("2d");
    charts["chartUsageTokens"] = new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: providers.map(esc),
        datasets: [{
          data: providers.map(p => byProvider[p].tokensIn + byProvider[p].tokensOut),
          backgroundColor: colors.slice(0, providers.length),
          borderColor: "#0d1117",
          borderWidth: 2,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        cutout: "50%",
        plugins: {
          title: { display: true, text: "Tokens per Provider", color: "#e6edf3" },
          legend: { labels: { color: "#e6edf3" } },
        },
      },
    });
  }

  // Bar chart: cost per provider
  const costCanvas = document.getElementById("chartUsageCost");
  if (costCanvas) {
    if (charts["chartUsageCost"]) charts["chartUsageCost"].destroy();
    const ctx = costCanvas.getContext("2d");
    charts["chartUsageCost"] = new Chart(ctx, {
      type: "bar",
      data: {
        labels: providers.map(esc),
        datasets: [{
          label: "Cost ($)",
          data: providers.map(p => byProvider[p].cost),
          backgroundColor: colors.slice(0, providers.length),
          borderColor: "#0d1117",
          borderWidth: 1,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          title: { display: true, text: "Cost per Provider", color: "#e6edf3" },
          legend: { display: false },
        },
        scales: {
          x: { ticks: { color: "#8b949e" }, grid: { color: "#21262d" } },
          y: { ticks: { color: "#8b949e" }, grid: { color: "#21262d" }, beginAtZero: true },
        },
      },
    });
  }
}

// ---- Charts ----
function renderCharts() {
  if (!state.health) return;
  const h = state.health;
  renderDoughnut("chartDiskRoot", "Root (/)", h.disk_root_pct || 0, ["#58a6ff", "#30363d"]);
  renderDoughnut("chartDiskHome", "Home (/home)", h.disk_home_pct || 0, ["#3fb950", "#30363d"]);
  renderDoughnut("chartMemory", "Memory", h.mem_pct || 0, ["#f0883e", "#30363d"]);
}

function renderDoughnut(canvasId, label, pct, colors) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  if (charts[canvasId]) charts[canvasId].destroy();
  const ctx = canvas.getContext("2d");
  charts[canvasId] = new Chart(ctx, {
    type: "doughnut",
    data: {
      labels: ["Used", "Free"],
      datasets: [{
        data: [pct, Math.max(0, 100 - pct)],
        backgroundColor: colors,
        borderColor: "#0d1117",
        borderWidth: 2,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      cutout: "65%",
      plugins: {
        legend: { display: false },
        tooltip: { callbacks: { label: ctx => ctx.raw + "%" } },
      },
    },
    plugins: [{
      id: "centerText",
      afterDraw(chart) {
        const { ctx, chartArea: { width, height, top, left } } = chart;
        ctx.save();
        ctx.fillStyle = "#e6edf3";
        ctx.font = "bold 18px -apple-system, sans-serif";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(pct + "%", left + width / 2, top + height / 2);
        ctx.restore();
      },
    }],
  });
}

// ---- Helpers ----
function esc(s) {
  if (s == null) return "";
  const div = document.createElement("div");
  div.textContent = String(s);
  return div.innerHTML;
}
