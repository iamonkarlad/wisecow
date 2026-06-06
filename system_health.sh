#!/usr/bin/env bash

# ─────────────────────────────────────────────
# System Health Monitoring Script
# Monitors CPU, Memory, Disk, and Processes
# Sends alerts to console and log file
# ─────────────────────────────────────────────

# ── Configuration ──────────────────────────
CPU_THRESHOLD=80        # Alert if CPU usage exceeds 80%
MEMORY_THRESHOLD=80     # Alert if Memory usage exceeds 80%
DISK_THRESHOLD=80       # Alert if Disk usage exceeds 80%
PROCESS_THRESHOLD=200   # Alert if running processes exceed 200
LOG_FILE="/var/log/system_health.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# ── Colors for console output ───────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ── Helper Functions ────────────────────────

# Print section header
print_header() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}   SYSTEM HEALTH MONITOR REPORT${NC}"
    echo -e "${CYAN}   $DATE${NC}"
    echo -e "${CYAN}========================================${NC}\n"
}

# Log message to file and console
log_message() {
    local level=$1
    local message=$2
    echo "[$DATE] [$level] $message" >> "$LOG_FILE"
}

# Print alert to console
print_alert() {
    local status=$1
    local metric=$2
    local value=$3
    local threshold=$4

    if [ "$status" == "ALERT" ]; then
        echo -e "${RED}[ALERT]${NC} $metric is at ${RED}$value%${NC} — exceeds threshold of $threshold%"
        log_message "ALERT" "$metric usage is $value% — exceeds threshold of $threshold%"
    elif [ "$status" == "WARNING" ]; then
        echo -e "${YELLOW}[WARNING]${NC} $metric is at ${YELLOW}$value%${NC} — approaching threshold of $threshold%"
        log_message "WARNING" "$metric usage is $value% — approaching threshold of $threshold%"
    else
        echo -e "${GREEN}[OK]${NC} $metric is at ${GREEN}$value%${NC} — within normal range"
        log_message "INFO" "$metric usage is $value% — OK"
    fi
}

# ── Check CPU Usage ─────────────────────────
check_cpu() {
    echo -e "${CYAN}── CPU Usage ──────────────────────────${NC}"

    # Get CPU usage percentage (idle subtracted from 100)
    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
    CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc 2>/dev/null || echo "0")
    CPU_USAGE=${CPU_USAGE%.*}  # Remove decimal

    # Fallback method if top format differs
    if [ -z "$CPU_USAGE" ] || [ "$CPU_USAGE" == "0" ]; then
        CPU_USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage)}')
    fi

    echo "  Current CPU Usage : $CPU_USAGE%"
    echo "  Threshold         : $CPU_THRESHOLD%"

    # Top 3 CPU consuming processes
    echo "  Top CPU Processes :"
    ps aux --sort=-%cpu | awk 'NR>1 && NR<=4 {printf "    %-20s %s%%\n", $11, $3}'

    # Determine status
    if [ "$CPU_USAGE" -ge "$CPU_THRESHOLD" ]; then
        print_alert "ALERT" "CPU" "$CPU_USAGE" "$CPU_THRESHOLD"
    elif [ "$CPU_USAGE" -ge $((CPU_THRESHOLD - 10)) ]; then
        print_alert "WARNING" "CPU" "$CPU_USAGE" "$CPU_THRESHOLD"
    else
        print_alert "OK" "CPU" "$CPU_USAGE" "$CPU_THRESHOLD"
    fi
}

# ── Check Memory Usage ──────────────────────
check_memory() {
    echo -e "\n${CYAN}── Memory Usage ───────────────────────${NC}"

    # Get memory info from /proc/meminfo
    TOTAL_MEM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    FREE_MEM=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    USED_MEM=$((TOTAL_MEM - FREE_MEM))
    MEMORY_USAGE=$((USED_MEM * 100 / TOTAL_MEM))

    # Convert to human readable
    TOTAL_GB=$(echo "scale=1; $TOTAL_MEM/1024/1024" | bc)
    USED_GB=$(echo "scale=1; $USED_MEM/1024/1024" | bc)
    FREE_GB=$(echo "scale=1; $FREE_MEM/1024/1024" | bc)

    echo "  Total Memory      : ${TOTAL_GB}GB"
    echo "  Used Memory       : ${USED_GB}GB"
    echo "  Free Memory       : ${FREE_GB}GB"
    echo "  Memory Usage      : $MEMORY_USAGE%"
    echo "  Threshold         : $MEMORY_THRESHOLD%"

    # Top 3 memory consuming processes
    echo "  Top Memory Processes :"
    ps aux --sort=-%mem | awk 'NR>1 && NR<=4 {printf "    %-20s %s%%\n", $11, $4}'

    # Determine status
    if [ "$MEMORY_USAGE" -ge "$MEMORY_THRESHOLD" ]; then
        print_alert "ALERT" "Memory" "$MEMORY_USAGE" "$MEMORY_THRESHOLD"
    elif [ "$MEMORY_USAGE" -ge $((MEMORY_THRESHOLD - 10)) ]; then
        print_alert "WARNING" "Memory" "$MEMORY_USAGE" "$MEMORY_THRESHOLD"
    else
        print_alert "OK" "Memory" "$MEMORY_USAGE" "$MEMORY_THRESHOLD"
    fi
}

# ── Check Disk Usage ────────────────────────
check_disk() {
    echo -e "\n${CYAN}── Disk Usage ─────────────────────────${NC}"

    # Check all mounted filesystems
    df -h | grep -vE '^Filesystem|tmpfs|cdrom|udev' | while read -r line; do
        DISK_USAGE=$(echo "$line" | awk '{print $5}' | cut -d'%' -f1)
        MOUNT=$(echo "$line" | awk '{print $6}')
        TOTAL=$(echo "$line" | awk '{print $2}')
        USED=$(echo "$line" | awk '{print $3}')
        FREE=$(echo "$line" | awk '{print $4}')

        echo "  Mount Point       : $MOUNT"
        echo "  Total / Used / Free : $TOTAL / $USED / $FREE"
        echo "  Disk Usage        : $DISK_USAGE%"
        echo "  Threshold         : $DISK_THRESHOLD%"

        if [ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]; then
            print_alert "ALERT" "Disk ($MOUNT)" "$DISK_USAGE" "$DISK_THRESHOLD"
        elif [ "$DISK_USAGE" -ge $((DISK_THRESHOLD - 10)) ]; then
            print_alert "WARNING" "Disk ($MOUNT)" "$DISK_USAGE" "$DISK_THRESHOLD"
        else
            print_alert "OK" "Disk ($MOUNT)" "$DISK_USAGE" "$DISK_THRESHOLD"
        fi
        echo ""
    done
}

# ── Check Running Processes ─────────────────
check_processes() {
    echo -e "\n${CYAN}── Running Processes ──────────────────${NC}"

    PROCESS_COUNT=$(ps aux | wc -l)
    # Subtract 1 for header line
    PROCESS_COUNT=$((PROCESS_COUNT - 1))

    echo "  Running Processes : $PROCESS_COUNT"
    echo "  Threshold         : $PROCESS_THRESHOLD"

    if [ "$PROCESS_COUNT" -ge "$PROCESS_THRESHOLD" ]; then
        echo -e "${RED}[ALERT]${NC} Process count $PROCESS_COUNT exceeds threshold of $PROCESS_THRESHOLD"
        log_message "ALERT" "Process count $PROCESS_COUNT exceeds threshold of $PROCESS_THRESHOLD"
    else
        echo -e "${GREEN}[OK]${NC} Process count $PROCESS_COUNT is within normal range"
        log_message "INFO" "Process count $PROCESS_COUNT — OK"
    fi

    # Show zombie processes if any
    ZOMBIE_COUNT=$(ps aux | awk '{print $8}' | grep -c 'Z' || true)
    if [ "$ZOMBIE_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}[WARNING]${NC} Found $ZOMBIE_COUNT zombie process(es)"
        log_message "WARNING" "Found $ZOMBIE_COUNT zombie processes"
    fi
}

# ── System Summary ──────────────────────────
print_summary() {
    echo -e "\n${CYAN}── System Information ─────────────────${NC}"
    echo "  Hostname    : $(hostname)"
    echo "  OS          : $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Kernel      : $(uname -r)"
    echo "  Uptime      : $(uptime -p)"
    echo "  Load Avg    : $(uptime | awk -F'load average:' '{print $2}')"
    echo -e "\n  Log file    : $LOG_FILE"
    echo -e "${CYAN}========================================${NC}\n"
}

# ── Main ────────────────────────────────────
main() {
    # Create log file if it doesn't exist
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/system_health.log"

    print_header
    log_message "INFO" "System health check started"

    check_cpu
    check_memory
    check_disk
    check_processes
    print_summary

    log_message "INFO" "System health check completed"
}

main
