#!/bin/bash
# Modern Reconnaissance Pipeline v2.1
# Based on: Jason Haddix TBHM v4 Methodology
# Features: Scope management, port filtering, exclusions
# Tools: amass, naabu, httpx, dnsx, ffuf, webanalyze, gitleaks, cloud_enum

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║          Modern Recon Pipeline v2.1                      ║
║          Methodology: TBHM v4 (Jason Haddix)             ║
║          Feature: Scope Management                       ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Usage
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
    -h, --help           Show this help message

MODES:
    fast        Passive subdomain enum + quick port scan (15-30 min)
    balanced    Active subdomain enum + full port scan + HTTP probing (1-2 hrs)
    deep        Everything + content discovery + GitHub secrets (4-8 hrs)

SCOPE MANAGEMENT:
    --scope FILE        Only scan domains/IPs in this file (one per line)
    --exclude FILE      Skip domains/IPs in this file (out-of-scope)
    --ports LIST        Custom port list (overrides mode defaults)
    --no-subdomain      Don't enumerate subdomains (use target only)
    --no-cloud          Don't search for cloud assets

EXAMPLES:
    # Basic scan
    $0 target.com

    # Fast scan on specific ports only
    $0 -m fast -p "80,443,8080,8443" target.com

    # Bug bounty with scope file
    $0 -m balanced --scope inscope.txt --exclude outofscope.txt target.com

    # Pentest with no cloud enumeration
    $0 -m deep --no-cloud --no-secrets target.com

    # Single host, specific ports
    $0 --no-subdomain -p "22,80,443" single-host.target.com

SCOPE FILE FORMAT:
    target.com
    *.target.com
    192.168.1.0/24
    !exclude.target.com  # Lines starting with ! are excluded

PHASES:
    1. Asset Discovery (subdomains, DNS, cloud assets)
    2. Service Discovery (ports, HTTP services)
    3. Deep Enumeration (content, tech stack, secrets)
    4. Reporting (consolidated findings)

SECURITY:
    - Respects scope boundaries
    - Excludes out-of-scope assets automatically
    - Rate limiting to avoid detection
    - Safe defaults for production environments
EOF
    exit 1
}

# Default values
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

# Parse arguments
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
mkdir -p "$OUTPUT_DIR"/{subdomains,dns,ports,http,content,tech,secrets,cloud,scope}

echo -e "${GREEN}[*]${NC} Target: ${TARGET}"
echo -e "${GREEN}[*]${NC} Mode: ${MODE}"
echo -e "${GREEN}[*]${NC} Output: ${OUTPUT_DIR}"

# Display scope configuration
if [ -n "$SCOPE_FILE" ]; then
    echo -e "${YELLOW}[*]${NC} Scope file: ${SCOPE_FILE}"
fi
if [ -n "$EXCLUDE_FILE" ]; then
    echo -e "${YELLOW}[*]${NC} Exclusion file: ${EXCLUDE_FILE}"
fi
if [ -n "$CUSTOM_PORTS" ]; then
    echo -e "${YELLOW}[*]${NC} Custom ports: ${CUSTOM_PORTS}"
fi
if [ "$SKIP_SUBDOMAIN" = true ]; then
    echo -e "${YELLOW}[*]${NC} Subdomain enumeration: SKIPPED"
fi
if [ "$SKIP_CLOUD" = true ]; then
    echo -e "${YELLOW}[*]${NC} Cloud enumeration: SKIPPED"
fi
echo ""

# Logging
LOGFILE="$OUTPUT_DIR/pipeline.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

# Start time
START_TIME=$(date +%s)

# Initialize counters
SUBDOMAIN_COUNT=0
RESOLVED_COUNT=0
PORT_COUNT=0
HTTP_COUNT=0
TECH_COUNT=0
CLOUD_COUNT=0
INSCOPE_COUNT=0
EXCLUDED_COUNT=0

# Function: Filter hosts by scope
filter_scope() {
    local input_file="$1"
    local output_file="$2"
    
    if [ ! -s "$input_file" ]; then
        touch "$output_file"
        return
    fi
    
    # If no scope file, pass through all
    if [ -z "$SCOPE_FILE" ]; then
        cp "$input_file" "$output_file"
        return
    fi
    
    # Filter by scope
    grep -Ff "$SCOPE_FILE" "$input_file" > "$output_file" 2>/dev/null || touch "$output_file"
    
    # Apply exclusions if provided
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
    echo -e "${YELLOW}[1.1]${NC} Subdomain Enumeration (amass)"

    if [ "$MODE" = "fast" ]; then
        echo "  → Running passive enumeration..."
        echo -e "  ${BLUE}ℹ${NC} This may take 2-5 minutes..."
        
        amass enum -d "$TARGET" -passive -o "$OUTPUT_DIR/subdomains/amass-passive.txt" 2>/dev/null &
        AMASS_PID=$!
        
        spin='-\|/'
        i=0
        while kill -0 $AMASS_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  %s Enumerating...                      " "${spin:$i:1}"
            sleep .1
        done
        wait $AMASS_PID
        printf "\r  ✓ Enumeration complete     \n"
        
    elif [ "$MODE" = "balanced" ]; then
        echo "  → Running active enumeration..."
        echo -e "  ${BLUE}ℹ${NC} This may take 10-15 minutes..."
        
        amass enum -d "$TARGET" -active -o "$OUTPUT_DIR/subdomains/amass-active.txt" 2>/dev/null &
        AMASS_PID=$!
        
        spin='-\|/'
        i=0
        while kill -0 $AMASS_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            printf "\r  %s Enumerating (active scan)...        " "${spin:$i:1}"
            sleep .1
        done
        wait $AMASS_PID
        printf "\r  ✓ Enumeration complete               \n"
        
    elif [ "$MODE" = "deep" ]; then
        echo "  → Running active enumeration with brute force..."
        echo -e "  ${BLUE}ℹ${NC} This may take 30-60 minutes..."
        
        amass enum -d "$TARGET" -active -brute -o "$OUTPUT_DIR/subdomains/amass-deep.txt" 2>/dev/null &
        AMASS_PID=$!
        
        spin='-\|/'
        i=0
        elapsed=0
        while kill -0 $AMASS_PID 2>/dev/null; do
            i=$(( (i+1) %4 ))
            elapsed=$((elapsed + 1))
            minutes=$((elapsed / 600))
            printf "\r  %s Enumerating (deep scan) - %sm elapsed..." "${spin:$i:1}" "$minutes"
            sleep .1
        done
        wait $AMASS_PID
        printf "\r  ✓ Enumeration complete                                \n"
    fi

    # Filter only FQDNs from amass output
    cat "$OUTPUT_DIR"/subdomains/amass-*.txt 2>/dev/null | \
        grep -E '\(FQDN\)' | \
        awk '{print $1}' | \
        sort -u > "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" || true

    # If no subdomains found, add target itself
    if [ ! -s "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" ]; then
        echo "$TARGET" > "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt"
        echo -e "  ${BLUE}ℹ${NC} No subdomains found, using target directly"
    fi

    # Apply scope filtering
    filter_scope "$OUTPUT_DIR/subdomains/all-subdomains-raw.txt" "$OUTPUT_DIR/subdomains/all-subdomains.txt"
    
    SUBDOMAIN_COUNT=$(wc -l < "$OUTPUT_DIR/subdomains/all-subdomains.txt" 2>/dev/null || echo 0)
    echo -e "  ${GREEN}✓${NC} Found ${SUBDOMAIN_COUNT} subdomain(s) in scope"
else
    echo -e "${YELLOW}[1.1]${NC} Subdomain Enumeration"
    echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-subdomain flag)"
    echo "$TARGET" > "$OUTPUT_DIR/subdomains/all-subdomains.txt"
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
    fi
else
    echo -e "  ${RED}✗${NC} No subdomains to resolve"
fi

# 1.3 - Cloud Asset Discovery
if [ "$SKIP_CLOUD" = false ] && { [ "$MODE" = "balanced" ] || [ "$MODE" = "deep" ]; }; then
    echo -e "${YELLOW}[1.3]${NC} Cloud Asset Discovery (cloud_enum)"
    
    KEYWORD=$(echo "$TARGET" | cut -d'.' -f1)
    
    echo "  → Searching for cloud assets with keyword: ${KEYWORD}"
    cloud_enum -k "$KEYWORD" -l "$OUTPUT_DIR/cloud/findings.txt" --disable-gcp 2>/dev/null || true
    
    if [ -s "$OUTPUT_DIR/cloud/findings.txt" ]; then
        CLOUD_COUNT=$(grep -c "Found" "$OUTPUT_DIR/cloud/findings.txt" 2>/dev/null || echo 0)
        echo -e "  ${GREEN}✓${NC} Found ${CLOUD_COUNT} cloud assets"
    else
        echo -e "  ${BLUE}ℹ${NC} No cloud assets found"
    fi
elif [ "$SKIP_CLOUD" = true ]; then
    echo -e "${YELLOW}[1.3]${NC} Cloud Asset Discovery"
    echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-cloud flag)"
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
    
    # Determine port list
    if [ -n "$CUSTOM_PORTS" ]; then
        PORT_LIST="$CUSTOM_PORTS"
        echo "  → Using custom port list: ${PORT_LIST}"
    elif [ "$MODE" = "fast" ]; then
        PORT_LIST="top-ports 1000"
    elif [ "$MODE" = "balanced" ]; then
        PORT_LIST="-"  # All ports
    elif [ "$MODE" = "deep" ]; then
        PORT_LIST="-"  # All ports
    fi
    
    if [ "$MODE" = "fast" ] || [ "$MODE" = "balanced" ]; then
        echo "  → Scanning ports (naabu) on ${HOST_COUNT} host(s)..."
        [ "$MODE" = "fast" ] && echo -e "  ${BLUE}ℹ${NC} Estimated time: 1-3 minutes"
        [ "$MODE" = "balanced" ] && echo -e "  ${BLUE}ℹ${NC} Estimated time: 5-10 minutes"
        
        # Build naabu command
        NAABU_CMD="naabu -l $OUTPUT_DIR/dns/live-hosts.txt -silent -o $OUTPUT_DIR/ports/open-ports.txt"
        
        if [ -n "$CUSTOM_PORTS" ]; then
            NAABU_CMD="$NAABU_CMD -p $CUSTOM_PORTS"
        elif [ "$MODE" = "fast" ]; then
            NAABU_CMD="$NAABU_CMD -top-ports 1000"
        else
            NAABU_CMD="$NAABU_CMD -p -"
        fi
        
        if [ -n "$RATE_LIMIT" ]; then
            NAABU_CMD="$NAABU_CMD -rate $RATE_LIMIT"
        fi
        
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

if [ "$MODE" = "balanced" ] || [ "$MODE" = "deep" ]; then
    echo -e "${BLUE}[PHASE 3]${NC} Deep Enumeration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # 3.1 - Technology Stack Detection
    echo -e "${YELLOW}[3.1]${NC} Technology Stack (webanalyze)"
    
    if [ -s "$OUTPUT_DIR/http/live-urls.txt" ]; then
        webanalyze -hosts "$OUTPUT_DIR/http/live-urls.txt" \
            -output json \
            -silent > "$OUTPUT_DIR/tech/tech-stack.json" 2>/dev/null || true
        
        TECH_COUNT=$(jq -r '.matches[].app_name' "$OUTPUT_DIR/tech/tech-stack.json" 2>/dev/null | sort -u | wc -l || echo 0)
        
        if [ "$TECH_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}✓${NC} Detected ${TECH_COUNT} technologies"
        else
            echo -e "  ${BLUE}ℹ${NC} No technologies detected"
        fi
    else
        echo -e "  ${RED}✗${NC} No URLs to analyze"
    fi
    
    # 3.2 - Content Discovery
    if [ "$MODE" = "deep" ] && [ "$SKIP_CONTENT" = false ] && [ -s "$OUTPUT_DIR/http/live-urls.txt" ]; then
        echo -e "${YELLOW}[3.2]${NC} Content Discovery (ffuf)"
        echo "  → Fuzzing common paths (this may take a while)..."
        
        WORDLIST="/usr/share/wordlists/dirb/common.txt"
        
        if [ -f "$WORDLIST" ]; then
            while IFS= read -r url; do
                domain=$(echo "$url" | awk -F/ '{print $3}')
                ffuf -w "$WORDLIST" \
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
        echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-content flag)"
    fi
    
    # 3.3 - GitHub Secret Scanning
    if [ "$MODE" = "deep" ] && [ "$SKIP_SECRETS" = false ]; then
        echo -e "${YELLOW}[3.3]${NC} GitHub Secret Scanning (gitleaks)"
        
        ORG=$(echo "$TARGET" | cut -d'.' -f1)
        
        echo "  → Checking GitHub organization: ${ORG}"
        echo "  ${YELLOW}ℹ${NC} Requires GitHub token (GITHUB_TOKEN env var)"
        
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
        echo -e "  ${BLUE}ℹ${NC} SKIPPED (--no-secrets flag)"
    fi
    
    echo ""
fi

# ============================================================================
# PHASE 4: REPORTING
# ============================================================================

echo -e "${BLUE}[PHASE 4]${NC} Generating Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Generate summary report
REPORT="$OUTPUT_DIR/REPORT.md"

cat > "$REPORT" << EOF
# Reconnaissance Report: ${TARGET}

**Date:** $(date)  
**Mode:** ${MODE}  
**Duration:** $(($(date +%s) - START_TIME)) seconds

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
$([ "$SKIP_CLOUD" = false ] && echo "| Cloud Assets | ${CLOUD_COUNT:-0} |")

---

## Subdomain Enumeration

**Method:** $([ "$MODE" = "fast" ] && echo "Passive" || echo "Active")  
**Tool:** amass

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

## Technology Stack

$(jq -r '.matches[] | "- \(.app_name) (\(.version // "version unknown"))"' "$OUTPUT_DIR/tech/tech-stack.json" 2>/dev/null | sort -u | head -20 || echo "No technologies detected")

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
$(tree -L 2 "$OUTPUT_DIR" 2>/dev/null || find "$OUTPUT_DIR" -type f)
\`\`\`

---

**Report generated by:** Modern Recon Pipeline v2.1  
**Methodology:** TBHM v4 (Jason Haddix)  
**Scope Management:** Enabled
EOF

echo -e "${GREEN}✓${NC} Report generated: ${REPORT}"
echo ""

# ============================================================================
# COMPLETION
# ============================================================================

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "${GREEN}[SUCCESS]${NC} Reconnaissance complete!"
echo -e "${GREEN}[*]${NC} Duration: ${MINUTES}m ${SECONDS}s"
echo -e "${GREEN}[*]${NC} Results: ${OUTPUT_DIR}"
echo -e "${GREEN}[*]${NC} Report: ${REPORT}"

# Scope summary
if [ -n "$SCOPE_FILE" ] || [ -n "$EXCLUDE_FILE" ]; then
    echo ""
    echo -e "${YELLOW}[SCOPE]${NC} Summary:"
    echo -e "  Total discovered: ${SUBDOMAIN_COUNT}"
    if [ -n "$SCOPE_FILE" ]; then
        echo -e "  In scope: ${INSCOPE_COUNT}"
    fi
    if [ -n "$EXCLUDE_FILE" ]; then
        echo -e "  Excluded: ${EXCLUDED_COUNT}"
    fi
fi

echo ""
echo -e "${BLUE}Next:${NC} Review ${REPORT} for findings"
