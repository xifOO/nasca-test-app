#!/bin/bash

set -e -o pipefail

SCRIPT_NAME="$(basename "$0")"
LOG_DIR="${LOG_DIR:-/tmp}"
CURL_TIMEOUT=5
LOG_FILE=""


log() {
    echo -e "$*"
    if [[ -n "$LOG_FILE" ]]; then
        echo -e "$*" >> "$LOG_FILE"
    fi
}


header() {
    log ""
    log "=== $* ==="
}


check_dependency() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        return 1
    fi
    return 0
}


timestamp() {
    date '+%Y%m%d_%H%M%S'
}


epoch_ms() {
    local ts
    ts="$(date +%s%3N 2>/dev/null || true)"
    if [[ "$ts" =~ ^[0-9]+$ ]]; then
        echo "$ts"
    else
        echo 0
    fi
}


init_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="${LOG_DIR%/}/${SCRIPT_NAME%.sh}_$(timestamp).log"
}


show_help() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] [URL...]
 
Собирает информацию о сервере и проверяет доступность сервисов по HTTP.
 
OPTIONS:
  --help    Показать эту справку
 
ARGUMENTS:
  URL       Один или несколько URL для проверки доступности (опционально)
 
 
EXAMPLES:
  $SCRIPT_NAME
  $SCRIPT_NAME http://localhost:5000/health
  $SCRIPT_NAME http://localhost:5000/health http://localhost:8080/health
  LOG_DIR=/var/log $SCRIPT_NAME http://localhost:5000/health

LOGGING:
  По умолчанию лог пишется в /tmp
  Имя файла: server-info_YYYYMMDD_HHMMSS.log

EXIT CODES:
  0   Все сервисы доступны (или URL не переданы)
  1   Один или более сервисов недоступны
EOF
}


print_system_info() {
    header "Server Diagnostics"
 
    local hostname os_name kernel uptime_str date_str
    date_str="$(date '+%Y-%m-%d %H:%M:%S')"
    hostname="$(hostname)"
    kernel="$(uname -r)"
 
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        os_name="$(. /etc/os-release && echo "${PRETTY_NAME}")"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        os_name="macOS $(sw_vers -productVersion)"
    else
        os_name="$(uname -s)"
    fi
 
    if command -v uptime &>/dev/null; then
        uptime_str="$(uptime | sed 's/.*up //' | sed 's/,.*//'| xargs)"
    else
        uptime_str="n/a"
    fi
 
    log "Date:     $date_str"
    log "Hostname: $hostname"
    log "OS:       $os_name"
    log "Kernel:   $kernel"
    log "Uptime:   $uptime_str"
}


print_resources() {
    header "Resources"
 
    local cpu_cores load_avg
    if command -v nproc &>/dev/null; then
        cpu_cores="$(nproc)"
    else
        cpu_cores="$(sysctl -n hw.ncpu 2>/dev/null || echo '?')"
    fi
    load_avg="$(uptime | awk -F'load average[s:]?' '{print $2}' | xargs)"
    log "CPU:      ${cpu_cores} cores, load average: ${load_avg}"
 
    if [[ -f /proc/meminfo ]]; then
        local mem_total_kb mem_avail_kb mem_used_kb mem_total_h mem_used_h mem_pct
        mem_total_kb="$(awk '/^MemTotal/ {print $2}' /proc/meminfo)"
        mem_avail_kb="$(awk '/^MemAvailable/ {print $2}' /proc/meminfo)"
        mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
        mem_total_h="$(numfmt --to=iec --suffix=B $((mem_total_kb * 1024)) 2>/dev/null || echo "${mem_total_kb}K")"
        mem_used_h="$(numfmt --to=iec --suffix=B $((mem_used_kb * 1024)) 2>/dev/null || echo "${mem_used_kb}K")"
        mem_pct=$(( mem_used_kb * 100 / mem_total_kb ))
        log "RAM:      ${mem_used_h} / ${mem_total_h} (${mem_pct}%)"
    elif command -v vm_stat &>/dev/null; then
        local mem_info
        mem_info="$(vm_stat | awk 'NR>1 && /Pages/ {sum+=$NF} END {printf "%.1fG used", sum*4096/1024/1024/1024}')"
        log "RAM:      ${mem_info}"
    else
        log "RAM:      n/a"
    fi
 
    local disk_output
    disk_output="$(df -h 2>/dev/null | awk 'NR==1 || /^\// {
        if (NR>1) printf "Disk %-6s %s / %s (%s)\n", $6":", $3, $2, $5
    }')"
    if [[ -n "$disk_output" ]]; then
        while IFS= read -r line; do
            log "$line"
        done <<< "$disk_output"
    else
        log "Disk:     n/a"
    fi
}


print_docker_info() {
    header "Docker"
 
    if ! check_dependency docker; then
        log "Docker:   not installed"
        return
    fi
 
    if ! docker info &>/dev/null 2>&1; then
        log "Docker:   installed but daemon is not running"
        return
    fi
 
    local containers
    containers="$(docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}' 2>/dev/null)"
 
    if [[ -z "$containers" ]]; then
        log "No running containers"
    else
        log "$containers"
    fi
}


check_services() {
    local urls=("$@")
    local healthy=0
    local total=${#urls[@]}
    local all_ok=true
 
    header "Service Health Checks"
 
    if ! check_dependency curl; then
        log "curl is not installed — skipping health checks"
        return 1
    fi
 
    for url in "${urls[@]}"; do
        local http_code elapsed
 
        local start_ms end_ms
        start_ms="$(epoch_ms)"
 
        if ! http_code="$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time "$CURL_TIMEOUT" \
            --connect-timeout "$CURL_TIMEOUT" \
            "$url" 2>/dev/null)"; then
            http_code="000"
        fi
 
        end_ms="$(epoch_ms)"
        elapsed=$(( end_ms - start_ms ))
 
        if [[ "$http_code" =~ ^2 ]]; then
            (( healthy++ )) || true
            log "[OK]   $url (${http_code}, ${elapsed}ms)"
        elif [[ "$http_code" == "000" ]]; then
            all_ok=false
            log "[FAIL] $url (connection refused)"
        else
            all_ok=false
            log "[FAIL] $url (${http_code}, ${elapsed}ms)"
        fi
    done
 
    log ""
    log "Result: ${healthy}/${total} services healthy"
 
    if [[ "$all_ok" == "false" ]]; then
        return 1
    fi
    return 0
}


main() {
    local urls=()
    for arg in "$@"; do
        case "$arg" in
            --help|-h)
                show_help
                exit 0
                ;;
            http://*|https://*)
                urls+=("$arg")
                ;;
            *)
                echo "Unknown argument: $arg" >&2
                echo "Run '$SCRIPT_NAME --help' for usage." >&2
                exit 1
                ;;
        esac
    done
 
    local exit_code=0

    init_logging
    log "Log file: $LOG_FILE"
 
    print_system_info
    print_resources
    print_docker_info
 
    if [[ ${#urls[@]} -gt 0 ]]; then
        check_services "${urls[@]}" || exit_code=1
    fi
 
    return "$exit_code"
}
 
main "$@"
