#!/bin/bash
# Recon Pipeline v3.0
# Methodology: TBHM v4 + Euphrates Integration
# Tools: subfinder, alterx, puredns, naabu, httpx, dnsx, nuclei, ffuf, gitleaks, cloud_enum

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
RESOLVERS="/home/ForeverLX/Tools/wordlists/SecLists/Miscellaneous/dns-resolvers.txt"
WORDLIST="/home/ForeverLX/Tools/wordlists/SecLists/Discovery/DNS/subdomains-top1million-20000.txt"

MODE="balanced"
OUTPUT_DIR=""
CUSTOM_PORTS=""
SCOPE_FILE=""
EXCLUDE_FILE=""
SKIP_SUBDOMAIN=false
SKIP_CLOUD=false
SKIP_CONTENT=false
SKIP_SECRETS=false
RATE_LIMIT=""
SHIELD_MODE=false
IP_TARGET=""
TARGET=""

usage() {
    cat << EOF
Usage: $0 [OPTIONS] <target>

OPTIONS:
    -m, --mode           Recon mode (fast|balanced|deep) [default: balanced]
    -o, --output         Output directory [default: ./recon-<target>]
    -p, --ports          Port list (e.g., "80,443,8080" or "1-1000") [default: mode-dependent]
    -s, --scope          Scope file (one domain/IP per line)
    -e, --exclude        Exclusion file (out-of-scope hosts)
    --no-subdomain       Skip subdomain enumeration
    --no-cloud           Skip cloud asset discovery
    --no-content         Skip content discovery (even in deep mode)
    --no-secrets         Skip GitHub secret scanning
    -r, --rate-limit     Rate limit for port scanning (packets/sec) [default: auto]
    --shield-mode        Passive-safe mode: no subdomain/cloud/secrets/content, fast ports, nuclei exposures only, writes REPORT.json
    --ip <address>       Direct IP target (implies --no-subdomain)
    --resolvers <path>   Custom resolvers file [default: SecLists dns-resolvers.txt]
    --wordlist <path>    Custom subdomain wordlist [default: SecLists subdomains-top1million-20000.txt]
    -h, --help           Show this help message

MODES:
    fast        Passive subdomain enum + quick port scan (15-30 min)
    balanced    Active subdomain enum + full port scan + HTTP probing (1-2 hrs)
    deep        Everything + content discovery + GitHub secrets (4-8 hrs)

EXAMPLES:
    $0 target.com
    $0 -m fast -p "80,443,8080,8443" target.com
    $0 -m balanced --scope inscope.txt --exclude outofscope.txt target.com
    $0 -m deep --no-cloud --no-secrets target.com
    $0 --no-subdomain -p "22,80,443" single-host.target.com
    $0 --shield-mode --ip 1.2.3.4 target.com
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -p|--ports)
            CUSTOM_PORTS="$2"
            shift 2
            ;;
        -s|--scope)
            SCOPE_FILE="$2"
            shift 2
            ;;
        -e|--exclude)
            EXCLUDE_FILE="$2"
            shift 2
            ;;
        --no-subdomain)
            SKIP_SUBDOMAIN=true
            shift
            ;;
        --no-cloud)
            SKIP_CLOUD=true
            shift
            ;;
        --no-content)
            SKIP_CONTENT=true
            shift
            ;;
        --no-secrets)
            SKIP_SECRETS=true
            shift
            ;;
        -r|--rate-limit)
            RATE_LIMIT="$2"
            shift 2
            ;;
        --shield-mode)
            SHIELD_MODE=true
            shift
            ;;
        --ip)
            IP_TARGET="$2"
            shift 2
            ;;
        --resolvers)
            RESOLVERS="$2"
            shift 2
            ;;
        --wordlist)
            WORDLIST="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1"
            usage
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done

# Apply shield mode implications
if [ "$SHIELD_MODE" = true ]; then
    SKIP_SUBDOMAIN=true
    SKIP_CLOUD=true
    SKIP_SECRETS=true
    SKIP_CONTENT=true
    MODE="fast"
fi

# Apply --ip implications
if [ -n "$IP_TARGET" ]; then
    SKIP_SUBDOMAIN=true
    if [ -z "$TARGET" ]; then
        TARGET="$IP_TARGET"
    fi
fi

# Validate target
if [ -z "${TARGET:-}" ]; then
    echo -e "${RED}[ERROR]${NC} Target domain required"
    usage
fi

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="./recon-${TARGET}"
fi

# Create output structure
mkdir -p "$OUTPUT_DIR"/{subdomains,dns,ports,http,content,tech,secrets,cloud,scope,nuclei}

# Banner
echo -e "${BLUE}"
SHIELD_STATUS=$([ "$SHIELD_MODE" = true ] && echo "ACTIVE" || echo "inactive")
cat << EOF
╔═══════════════════════════════════════════════════════════╗
║          Recon Pipeline v3.0                             ║
║          Methodology: TBHM v4 + Euphrates Integration    ║
║          Shield Mode: ${SHIELD_STATUS}                            ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}[*]${NC} Target: ${TARGET}"
[ -n "$IP_TARGET" ] && echo -e "${GREEN}[*]${NC} IP: ${IP_TARGET}"
echo -e "${GREEN}[*]${NC} Mode: ${MODE}"
echo -e "${GREEN}[*]${NC} Output: ${OUTPUT_DIR}"

[ -n "$SCOPE_FILE" ]   && echo -e "${YELLOW}[*]${NC} Scope file: ${SCOPE_FILE}"
[ -n "$EXCLUDE_FILE" ] && echo -e "${YELLOW}[*]${NC} Exclusion file: ${EXCLUDE_FILE}"
[ -n "$CUSTOM_PORTS" ] && echo -e "${YELLOW}[*]${NC} Custom ports: ${CUSTOM_PORTS}"
[ "$SKIP_SUBDOMAIN" = true ] && echo -e "${YELLOW}[*]${NC} Subdomain enumeration: SKIPPED"
[ "$SKIP_CLOUD" = true ]     && echo -e "${YELLOW}[*]${NC} Cloud enumeration: SKIPPED"
echo ""

# Logging
LOGFILE="$OUTPUT_DIR/pipeline.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

START_TIME=$(date +%s)

# Counters
SUBDOMAIN_COUNT=0
RESOLVED_COUNT=0
PORT_COUNT=0
HTTP_COUNT=0
TECH_COUNT=0
CLOUD_COUNT=0
NUCLEI_COUNT=0
INSCOPE_COUNT=0
EXCLUDED_COUNT=0

filter_scope() {
    local input_file="$1"
    local output_file="$2"

    if [ ! -s "$input_file" ]; then
        touch "$output_file"
        return
    fi

    if [ -z "$SCOPE_FILE" ]; then
        cp "$input_file" "$output_file"
        return
    fi

    grep -Ff "$SCOPE_FILE" "$input_file" > "$output_file" 2>/dev/null || touch "$output_file"

    if [ -n "$EXCLUDE_FILE" ] && [ -s "$EXCLUDE_FILE" ]; then
        local temp_file
        temp_file=$(mktemp)
        grep -vFf "$EXCLUDE_FILE" "$output_file" > "$temp_file" 2>/dev/null || touch "$temp_file"
        mv "$temp_file" "$output_file"
    fi

    INSCOPE_COUNT=$(wc -l < "$output_file" 2>/dev/null || echo 0)
}

# ============================================================================
# PHASE 1: ASSET DISCOVERY
# ============================================================================

echo -e "${BLUE}[PHASE 1]${NC} Asset Discovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1.1 - Subdomain Enumeration
if [ "$SKIP_SUBDOMAIN" = false ]; then
    echo -e "${YELLOW}[1.1]${NC} Subdomain Enumeration (subfinder + alterx + puredns)"

    if [ "$MODE" = "fast" ]; then
        echo "  → Running passive enumeration (subfinder)..."
        subfinder -d "$TARGET" -silent -o "$OUTPUT_DIR/subdomains/subfinder.txt" 2>/dev/null || true
        cp "$OUTPUT_DIR/subdomains/subfinder.txt" "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" 2>/dev/null || true

    elif [ "$MODE" = "balanced" ]; then
        echo "  → Running active enumeration (subfinder + alterx + puredns resolve)..."
        subfinder -d "$TARGET" -all -silent -o "$OUTPUT_DIR/subdomains/subfinder.txt" 2>/dev/null || true
        alterx -l "$OUTPUT_DIR/subdomains/subfinder.txt" -silent \
            -o "$OUTPUT_DIR/subdomains/alterx-perms.txt" 2>/dev/null || true
        cat "$OUTPUT_DIR/subdomains/subfinder.txt" "$OUTPUT_DIR/subdomains/alterx-perms.txt" \
            2>/dev/null | sort -u > "$OUTPUT_DIR/subdomains/combined.txt"
        puredns resolve "$OUTPUT_DIR/subdomains/combined.txt" \
            -r "$RESOLVERS" --write "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" -q 2>/dev/null || true

    elif [ "$MODE" = "deep" ]; then
        echo "  → Running deep enumeration (subfinder + puredns brute + alterx + puredns resolve)..."
        subfinder -d "$TARGET" -all -silent -o "$OUTPUT_DIR/subdomains/subfinder.txt" 2>/dev/null || true
        puredns bruteforce "$WORDLIST" "$TARGET" \
            -r "$RESOLVERS" --write "$OUTPUT_DIR/subdomains/puredns-brute.txt" -q 2>/dev/null || true
        alterx -l "$OUTPUT_DIR/subdomains/subfinder.txt" -silent \
            -o "$OUTPUT_DIR/subdomains/alterx-perms.txt" 2>/dev/null || true
        cat "$OUTPUT_DIR/subdomains/subfinder.txt" \
            "$OUTPUT_DIR/subdomains/puredns-brute.txt" \
            "$OUTPUT_DIR/subdomains/alterx-perms.txt" \
            2>/dev/null | sort -u > "$OUTPUT_DIR/subdomains/combined.txt"
        puredns resolve "$OUTPUT_DIR/subdomains/combined.txt" \
            -r "$RESOLVERS" --write "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" -q 2>/dev/null || true
    fi

    # Fallback: if nothing resolved, seed with target
    if [ ! -s "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" ]; then
        echo "$TARGET" > "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt"
        echo -e "  ${BLUE}ℹ${NC} No subdomains found, using target directly"
    fi

    filter_scope "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" "$OUTPUT_DIR/subdomains/all-subdomains.txt"

    SUBDOMAIN_COUNT=$(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt" 2>/dev/null || echo 0)
    echo -e "  ${GREEN}✓${NC} Found ${SUBDOMAIN_COUNT} subdomain(s) in scope"
else
    echo -e "${YELLOW}[1.1]${NC} Subdomain Enumeration"
    echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-subdomain / --shield-mode / --ip flag)"
    if [ -n "$IP_TARGET" ]; then
        echo "$IP_TARGET" > "$OUTPUT_DIR/subdomains/all-subdomains.txt"
    else
        echo "$TARGET" > "$OUTPUT_DIR/subdomains/all-subdomains.txt"
    fi
    SUBDOMAIN_COUNT=1
fi

# 1.2 - DNS Resolution
echo -e "${YELLOW}[1.2]${NC} DNS Resolution (dnsx)"
if [ -s "$OUTPUT_DIR/subdomains/all-subdomains.txt" ]; then
    dnsx -l "$OUTPUT_DIR/subdomains/all-subdomains.txt" -a -resp -silent -o "$OUTPUT_DIR/dns/resolved.txt" 2>/dev/null || true
    RESOLVED_COUNT=$(wc -l < "$OUTPUT_DIR/dns/resolved.txt" 2>/dev/null || echo 0)

    if [ "$RESOLVED_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Resolved ${RESOLVED_COUNT} domain(s)"
        cut -d' ' -f1 "$OUTPUT_DIR/dns/resolved.txt" > "$OUTPUT_DIR/dns/live-hosts.txt" 2>/dev/null || true
    else
        echo -e "  ${RED}✗${NC} No domains resolved"
        # If IP target provided, use it directly for downstream phases
        if [ -n "$IP_TARGET" ]; then
            echo "$IP_TARGET" > "$OUTPUT_DIR/dns/live-hosts.txt"
            RESOLVED_COUNT=1
            echo -e "  ${BLUE}ℹ${NC} Using --ip target directly: ${IP_TARGET}"
        fi
    fi
else
    echo -e "  ${RED}✗${NC} No subdomains to resolve"
fi

# 1.3 - Cloud Asset Discovery
if [ "$SKIP_CLOUD" = false ] && { [ "$MODE" = "balanced" ] || [ "$MODE" = "deep" ]; }; then
    echo -e "${YELLOW}[1.3]${NC} Cloud Asset Discovery (cloud_enum)"

    KEYWORD=$(echo "$TARGET" | cut -d'.' -f1)
    echo "  → Searching for cloud assets with keyword: ${KEYWORD}"

    if command -v cloud_enum &>/dev/null; then
        cloud_enum -k "$KEYWORD" -l "$OUTPUT_DIR/cloud/findings.txt" --disable-gcp 2>/dev/null || true

        if [ -s "$OUTPUT_DIR/cloud/findings.txt" ]; then
            CLOUD_COUNT=$(grep -c "Found" "$OUTPUT_DIR/cloud/findings.txt" 2>/dev/null || echo 0)
            echo -e "  ${GREEN}✓${NC} Found ${CLOUD_COUNT} cloud assets"
        else
            echo -e "  ${BLUE}ℹ${NC} No cloud assets found"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} cloud_enum not in PATH, skipping"
    fi
elif [ "$SKIP_CLOUD" = true ]; then
    echo -e "${YELLOW}[1.3]${NC} Cloud Asset Discovery"
    echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-cloud / --shield-mode flag)"
fi

echo ""

# ============================================================================
# PHASE 2: SERVICE DISCOVERY
# ============================================================================

echo -e "${BLUE}[PHASE 2]${NC} Service Discovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 2.1 - Port Scanning
echo -e "${YELLOW}[2.1]${NC} Port Scanning"

if [ -s "$OUTPUT_DIR/dns/live-hosts.txt" ]; then
    HOST_COUNT=$(wc -l < "$OUTPUT_DIR/dns/live-hosts.txt")

    if [ -n "$CUSTOM_PORTS" ]; then
        echo "  → Using custom port list: ${CUSTOM_PORTS}"
    fi

    if [ "$MODE" = "fast" ] || [ "$MODE" = "balanced" ] || [ "$SHIELD_MODE" = true ]; then
        [ "$MODE" = "fast" ]     && echo -e "  ${BLUE}ℹ${NC} Estimated time: 1-3 minutes"
        [ "$MODE" = "balanced" ] && echo -e "  ${BLUE}ℹ${NC} Estimated time: 5-10 minutes"
        echo "  → Scanning ports (naabu) on ${HOST_COUNT} host(s)..."

        NAABU_CMD="naabu -l $OUTPUT_DIR/dns/live-hosts.txt -silent -o $OUTPUT_DIR/ports/open-ports.txt"

        if [ -n "$CUSTOM_PORTS" ]; then
            NAABU_CMD="$NAABU_CMD -p $CUSTOM_PORTS"
        elif [ "$MODE" = "fast" ] || [ "$SHIELD_MODE" = true ]; then
            NAABU_CMD="$NAABU_CMD -top-ports 1000"
        else
            NAABU_CMD="$NAABU_CMD -p -"
        fi

        [ -n "$RATE_LIMIT" ] && NAABU_CMD="$NAABU_CMD -rate $RATE_LIMIT"

        eval "$NAABU_CMD" 2>/dev/null &
        NAABU_PID=$!

        spin='-\|/'
        i=0
        while kill -0 $NAABU_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  %s Scanning ports..." "${spin:$i:1}"
            sleep .1
        done
        wait $NAABU_PID
        printf "\r  ✓ Port scan complete     \n"

    elif [ "$MODE" = "deep" ]; then
        echo "  → Fast port discovery (rustscan) + service detection (nmap)..."
        echo -e "  ${BLUE}ℹ${NC} Estimated time: 10-20 minutes"

        current=0
        while IFS= read -r host; do
            current=$((current + 1))
            printf "\r  [%d/%d] Scanning %s..." "$current" "$HOST_COUNT" "$host"

            if [ -n "$CUSTOM_PORTS" ]; then
                rustscan -a "$host" --ulimit 5000 -p "$CUSTOM_PORTS" -- -sV -sC -oN "$OUTPUT_DIR/ports/${host}-nmap.txt" 2>/dev/null || true
            else
                rustscan -a "$host" --ulimit 5000 -- -sV -sC -oN "$OUTPUT_DIR/ports/${host}-nmap.txt" 2>/dev/null || true
            fi
        done < "$OUTPUT_DIR/dns/live-hosts.txt"
        printf "\n"

        grep -h "open" "$OUTPUT_DIR"/ports/*-nmap.txt 2>/dev/null | awk '{print $1}' | sort -u > "$OUTPUT_DIR/ports/open-ports.txt" || true
    fi

    PORT_COUNT=$(wc -l < "$OUTPUT_DIR/ports/open-ports.txt" 2>/dev/null || echo 0)
    echo -e "  ${GREEN}✓${NC} Found ${PORT_COUNT} open port(s)"
else
    echo -e "  ${RED}✗${NC} No live hosts to scan"
fi

# 2.2 - HTTP Service Probing
echo -e "${YELLOW}[2.2]${NC} HTTP Service Probing (httpx)"

if [ -s "$OUTPUT_DIR/dns/live-hosts.txt" ]; then
    httpx -l "$OUTPUT_DIR/dns/live-hosts.txt" \
        -tech-detect \
        -status-code \
        -title \
        -json \
        -silent \
        -o "$OUTPUT_DIR/http/http-services.json" 2>/dev/null || true

    HTTP_COUNT=$(wc -l < "$OUTPUT_DIR/http/http-services.json" 2>/dev/null || echo 0)

    if [ "$HTTP_COUNT" -gt 0 ]; then
        echo -e "  ${GREEN}✓${NC} Found ${HTTP_COUNT} HTTP service(s)"
        jq -r '.url' "$OUTPUT_DIR/http/http-services.json" 2>/dev/null | sort -u > "$OUTPUT_DIR/http/live-urls.txt" || true
    else
        echo -e "  ${BLUE}ℹ${NC} No HTTP services found"
    fi
else
    echo -e "  ${RED}✗${NC} No hosts to probe"
fi

echo ""

# ============================================================================
# PHASE 3: DEEP ENUMERATION
# ============================================================================

echo -e "${BLUE}[PHASE 3]${NC} Deep Enumeration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 3.0 - Nuclei Scan
echo -e "${YELLOW}[3.0]${NC} Vulnerability / Exposure Scan (nuclei)"

NUCLEI_FINDINGS="$OUTPUT_DIR/nuclei/findings.jsonl"

if [ -s "$OUTPUT_DIR/http/live-urls.txt" ]; then
    if [ "$SHIELD_MODE" = true ]; then
        echo "  → Shield mode: exposures + misconfigurations + exposed-panels only..."
        nuclei -l "$OUTPUT_DIR/http/live-urls.txt" \
            -t "$HOME/nuclei-templates/http/exposures/" \
            -t "$HOME/nuclei-templates/http/misconfiguration/" \
            -t "$HOME/nuclei-templates/http/exposed-panels/" \
            -severity critical,high,medium,info \
            -je "$NUCLEI_FINDINGS" \
            -silent \
            -no-interactsh \
            2>/dev/null || true
    else
        echo "  → Running curated template set (exposures, technologies, misconfigurations, exposed-panels, network)..."
        nuclei -l "$OUTPUT_DIR/http/live-urls.txt" \
            -t "$HOME/nuclei-templates/http/exposures/" \
            -t "$HOME/nuclei-templates/http/technologies/" \
            -t "$HOME/nuclei-templates/http/misconfiguration/" \
            -t "$HOME/nuclei-templates/http/exposed-panels/" \
            -t "$HOME/nuclei-templates/network/" \
            -severity critical,high,medium \
            -je "$NUCLEI_FINDINGS" \
            -silent \
            -no-interactsh \
            2>/dev/null || true
    fi

    NUCLEI_COUNT=$(wc -l < "$NUCLEI_FINDINGS" 2>/dev/null || echo 0)
    echo -e "  ${GREEN}✓${NC} Nuclei found ${NUCLEI_COUNT} finding(s)"
else
    echo -e "  ${BLUE}ℹ${NC} No live URLs — skipping nuclei"
    NUCLEI_COUNT=0
fi

# 3.1 - Technology Stack (httpx --tech-detect already ran in 2.2; surface results)
if [ "$MODE" = "balanced" ] || [ "$MODE" = "deep" ]; then
    echo -e "${YELLOW}[3.1]${NC} Technology Stack"

    if [ -s "$OUTPUT_DIR/http/http-services.json" ]; then
        TECH_COUNT=$(jq -r '.technologies[]?' "$OUTPUT_DIR/http/http-services.json" 2>/dev/null | sort -u | wc -l || echo 0)
        if [ "$TECH_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} Detected ${TECH_COUNT} technologies (via httpx --tech-detect)"
        else
            echo -e "  ${BLUE}ℹ${NC} No technologies detected"
        fi
    else
        echo -e "  ${RED}✗${NC} No HTTP services data"
    fi

    # 3.2 - Content Discovery
    if [ "$MODE" = "deep" ] && [ "$SKIP_CONTENT" = false ] && [ -s "$OUTPUT_DIR/http/live-urls.txt" ]; then
        echo -e "${YELLOW}[3.2]${NC} Content Discovery (ffuf)"
        echo "  → Fuzzing common paths..."

        CONTENT_WORDLIST="/usr/share/wordlists/dirb/common.txt"

        if [ -f "$CONTENT_WORDLIST" ]; then
            while IFS= read -r url; do
                domain=$(echo "$url" | awk -F/ '{print $3}')
                ffuf -w "$CONTENT_WORDLIST" \
                    -u "${url}/FUZZ" \
                    -mc 200,301,302,401,403 \
                    -o "$OUTPUT_DIR/content/${domain}-ffuf.json" \
                    -of json \
                    -s \
                    2>/dev/null || true
            done < "$OUTPUT_DIR/http/live-urls.txt"

            echo -e "  ${GREEN}✓${NC} Content discovery complete"
        else
            echo -e "  ${YELLOW}⚠${NC} Wordlist not found, skipping"
        fi
    elif [ "$SKIP_CONTENT" = true ]; then
        echo -e "${YELLOW}[3.2]${NC} Content Discovery"
        echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-content / --shield-mode flag)"
    fi

    # 3.3 - GitHub Secret Scanning
    if [ "$MODE" = "deep" ] && [ "$SKIP_SECRETS" = false ]; then
        echo -e "${YELLOW}[3.3]${NC} GitHub Secret Scanning (gitleaks)"

        ORG=$(echo "$TARGET" | cut -d'.' -f1)
        echo "  → Checking GitHub organization: ${ORG}"
        echo -e "  ${YELLOW}ℹ${NC} Requires GitHub token (GITHUB_TOKEN env var)"

        if [ -n "${GITHUB_TOKEN:-}" ]; then
            gitleaks detect \
                --source "https://github.com/${ORG}" \
                --report-path "$OUTPUT_DIR/secrets/gitleaks-report.json" \
                --verbose 2>/dev/null || true

            if [ -s "$OUTPUT_DIR/secrets/gitleaks-report.json" ]; then
                SECRET_COUNT=$(jq length "$OUTPUT_DIR/secrets/gitleaks-report.json" 2>/dev/null || echo 0)
                echo -e "  ${GREEN}✓${NC} Found ${SECRET_COUNT} potential secret(s)"
            else
                echo -e "  ${BLUE}ℹ${NC} No secrets found"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} Skipping (no GITHUB_TOKEN set)"
        fi
    elif [ "$SKIP_SECRETS" = true ]; then
        echo -e "${YELLOW}[3.3]${NC} GitHub Secret Scanning"
        echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-secrets / --shield-mode flag)"
    fi
fi

echo ""

# ============================================================================
# PHASE 4: REPORTING
# ============================================================================

echo -e "${BLUE}[PHASE 4]${NC} Generating Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

REPORT="$OUTPUT_DIR/REPORT.md"

cat > "$REPORT" << EOF
# Reconnaissance Report: ${TARGET}

**Date:** $(date)
**Mode:** ${MODE}$([ "$SHIELD_MODE" = true ] && echo " (shield)")
**Duration:** ${DURATION} seconds
$([ -n "$IP_TARGET" ] && echo "**IP Target:** ${IP_TARGET}")

---

## Scope Configuration

| Setting | Value |
|---------|-------|
| Subdomain Enum | $([ "$SKIP_SUBDOMAIN" = true ] && echo "Disabled" || echo "Enabled") |
| Cloud Discovery | $([ "$SKIP_CLOUD" = true ] && echo "Disabled" || echo "Enabled") |
| Content Discovery | $([ "$SKIP_CONTENT" = true ] && echo "Disabled" || echo "Enabled") |
| Secret Scanning | $([ "$SKIP_SECRETS" = true ] && echo "Disabled" || echo "Enabled") |
| Custom Ports | $([ -n "$CUSTOM_PORTS" ] && echo "$CUSTOM_PORTS" || echo "Mode default") |
| Scope File | $([ -n "$SCOPE_FILE" ] && echo "$SCOPE_FILE" || echo "None") |
| Exclusion File | $([ -n "$EXCLUDE_FILE" ] && echo "$EXCLUDE_FILE" || echo "None") |

---

## Summary

| Metric | Count |
|--------|-------|
| Subdomains Discovered | ${SUBDOMAIN_COUNT} |
| Live Hosts | ${RESOLVED_COUNT} |
| Open Ports | ${PORT_COUNT} |
| HTTP Services | ${HTTP_COUNT} |
| Technologies Detected | ${TECH_COUNT:-0} |
| Nuclei Findings | ${NUCLEI_COUNT:-0} |
$([ "$SKIP_CLOUD" = false ] && echo "| Cloud Assets | ${CLOUD_COUNT:-0} |")

---

## Subdomain Enumeration

**Method:** $([ "$MODE" = "fast" ] && echo "Passive (subfinder)" || echo "Active (subfinder + alterx + puredns)")

\`\`\`
$(head -20 "$OUTPUT_DIR/subdomains/all-subdomains.txt" 2>/dev/null || echo "No subdomains found")
\`\`\`

$([ "${SUBDOMAIN_COUNT}" -gt 20 ] && echo "*(Showing first 20 of ${SUBDOMAIN_COUNT} total)*")

---

## Live HTTP Services

\`\`\`
$(head -20 "$OUTPUT_DIR/http/live-urls.txt" 2>/dev/null || echo "No HTTP services found")
\`\`\`

$([ "${HTTP_COUNT}" -gt 20 ] && echo "*(Showing first 20 of ${HTTP_COUNT} total)*")

---

## Nuclei Findings

$([ "${NUCLEI_COUNT}" -gt 0 ] && jq -r '"\(.info.severity | ascii_upcase) | \(.info.name) | \(.host)"' "$NUCLEI_FINDINGS" 2>/dev/null | head -50 || echo "No findings")

$([ "${NUCLEI_COUNT}" -gt 50 ] && echo "*(Showing first 50 of ${NUCLEI_COUNT} total — see nuclei/findings.jsonl)*")

---

## Technology Stack

$(jq -r '.technologies[]?' "$OUTPUT_DIR/http/http-services.json" 2>/dev/null | sort -u | head -20 || echo "No technologies detected")

---

## Next Steps

1. **Manual Review:** Review HTTP services for interesting targets
2. **Screenshot:** Take screenshots of high-value targets
3. **Deep Dive:** Focus on specific services for vulnerability testing
4. **Content Discovery:** Run deeper content discovery on key targets
5. **Authentication:** Test for default credentials

---

## File Structure

\`\`\`
$(find "$OUTPUT_DIR" -type f 2>/dev/null | sort)
\`\`\`

---

**Report generated by:** Recon Pipeline v3.0
**Methodology:** TBHM v4 + Euphrates Integration
**Scope Management:** Enabled
EOF

echo -e "${GREEN}✓${NC} Report generated: ${REPORT}"

# Shield mode: write REPORT.json
if [ "$SHIELD_MODE" = true ]; then
    REPORT_JSON="$OUTPUT_DIR/REPORT.json"
    TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if command -v jq &>/dev/null; then
        OPEN_PORTS_ARR=$([ -s "$OUTPUT_DIR/ports/open-ports.txt" ] && \
            jq -R -s '[split("\n")[] | select(length>0)]' "$OUTPUT_DIR/ports/open-ports.txt" || \
            echo "[]")
        HTTP_SERVICES_ARR=$([ -s "$OUTPUT_DIR/http/http-services.json" ] && \
            jq -s '[.[].url // empty]' "$OUTPUT_DIR/http/http-services.json" || \
            echo "[]")
        NUCLEI_FINDINGS_ARR=$([ -s "$NUCLEI_FINDINGS" ] && \
            jq -s '.' "$NUCLEI_FINDINGS" || \
            echo "[]")
        CRIT_COUNT=$([ -s "$NUCLEI_FINDINGS" ] && \
            jq -s '[.[] | select(.info.severity=="critical")] | length' "$NUCLEI_FINDINGS" || echo 0)
        HIGH_COUNT=$([ -s "$NUCLEI_FINDINGS" ] && \
            jq -s '[.[] | select(.info.severity=="high")] | length' "$NUCLEI_FINDINGS" || echo 0)
        MED_COUNT=$([ -s "$NUCLEI_FINDINGS" ] && \
            jq -s '[.[] | select(.info.severity=="medium")] | length' "$NUCLEI_FINDINGS" || echo 0)

        jq -n \
            --arg target "$TARGET" \
            --arg ip "${IP_TARGET:-}" \
            --arg timestamp "$TS" \
            --arg mode "shield" \
            --argjson duration "$DURATION" \
            --argjson open_ports "$OPEN_PORTS_ARR" \
            --argjson http_services "$HTTP_SERVICES_ARR" \
            --argjson nuclei_findings "$NUCLEI_FINDINGS_ARR" \
            --argjson port_count "$PORT_COUNT" \
            --argjson http_count "$HTTP_COUNT" \
            --argjson nuclei_count "$NUCLEI_COUNT" \
            --argjson critical "$CRIT_COUNT" \
            --argjson high "$HIGH_COUNT" \
            --argjson medium "$MED_COUNT" \
            '{
                target: $target,
                ip: $ip,
                timestamp: $timestamp,
                mode: $mode,
                duration_seconds: $duration,
                open_ports: $open_ports,
                http_services: $http_services,
                nuclei_findings: $nuclei_findings,
                summary: {
                    port_count: $port_count,
                    http_count: $http_count,
                    nuclei_count: $nuclei_count,
                    critical: $critical,
                    high: $high,
                    medium: $medium
                }
            }' > "$REPORT_JSON"
    else
        # jq not available — summary-only fallback
        printf '{"target":"%s","ip":"%s","timestamp":"%s","mode":"shield","duration_seconds":%d,"summary":{"port_count":%d,"http_count":%d,"nuclei_count":%d}}\n' \
            "$TARGET" "${IP_TARGET:-}" "$TS" "$DURATION" "$PORT_COUNT" "$HTTP_COUNT" "$NUCLEI_COUNT" > "$REPORT_JSON"
    fi

    echo -e "${GREEN}✓${NC} JSON report generated: ${REPORT_JSON}"
fi

echo ""

# ============================================================================
# COMPLETION
# ============================================================================

MINUTES=$((DURATION / 60))
SECS=$((DURATION % 60))

echo -e "${GREEN}[SUCCESS]${NC} Reconnaissance complete!"
echo -e "${GREEN}[*]${NC} Duration: ${MINUTES}m ${SECS}s"
echo -e "${GREEN}[*]${NC} Results: ${OUTPUT_DIR}"
echo -e "${GREEN}[*]${NC} Report: ${REPORT}"

if [ -n "$SCOPE_FILE" ] || [ -n "$EXCLUDE_FILE" ]; then
    echo ""
    echo -e "${YELLOW}[SCOPE]${NC} Summary:"
    echo -e "  Total discovered: ${SUBDOMAIN_COUNT}"
    [ -n "$SCOPE_FILE" ]   && echo -e "  In scope: ${INSCOPE_COUNT}"
    [ -n "$EXCLUDE_FILE" ] && echo -e "  Excluded: ${EXCLUDED_COUNT}"
fi

echo ""
echo -e "${BLUE}Next:${NC} Review ${REPORT} for findings"
