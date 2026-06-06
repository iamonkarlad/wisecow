#!/usr/bin/env python3

# ─────────────────────────────────────────────
# Application Health Checker
# Checks uptime and health of applications
# via HTTP status codes
# ─────────────────────────────────────────────

import urllib.request
import urllib.error
import json
import time
import datetime
import sys
import socket

# ── Configuration ───────────────────────────
# Add your applications here
APPLICATIONS = [
    {
        "name": "Wisecow App",
        "url": "http://localhost:4499",
        "timeout": 5,
        "expected_status": 200
    },
    {
        "name": "Google",
        "url": "https://www.google.com",
        "timeout": 5,
        "expected_status": 200
    },
    {
        "name": "GitHub",
        "url": "https://github.com",
        "timeout": 5,
        "expected_status": 200
    }
]

LOG_FILE = "/tmp/app_health.log"
CHECK_INTERVAL = 60  # seconds between checks (for continuous mode)

# ── Colors ───────────────────────────────────
class Colors:
    RED    = '\033[0;31m'
    GREEN  = '\033[0;32m'
    YELLOW = '\033[1;33m'
    CYAN   = '\033[0;36m'
    RESET  = '\033[0m'

# ── Logger ───────────────────────────────────
def log(level, message):
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"[{timestamp}] [{level}] {message}\n"
    with open(LOG_FILE, 'a') as f:
        f.write(log_entry)

# ── Print Header ─────────────────────────────
def print_header():
    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"\n{Colors.CYAN}{'='*50}{Colors.RESET}")
    print(f"{Colors.CYAN}   APPLICATION HEALTH CHECKER{Colors.RESET}")
    print(f"{Colors.CYAN}   {now}{Colors.RESET}")
    print(f"{Colors.CYAN}{'='*50}{Colors.RESET}\n")

# ── Check Single Application ─────────────────
def check_application(app):
    name     = app['name']
    url      = app['url']
    timeout  = app['timeout']
    expected = app['expected_status']

    result = {
        "name"            : name,
        "url"             : url,
        "status"          : None,
        "response_time_ms": None,
        "http_code"       : None,
        "is_up"           : False,
        "message"         : ""
    }

    start_time = time.time()

    try:
        # Make HTTP request
        req = urllib.request.Request(
            url,
            headers={'User-Agent': 'HealthChecker/1.0'}
        )
        response = urllib.request.urlopen(req, timeout=timeout)
        end_time = time.time()

        http_code = response.getcode()
        response_time = round((end_time - start_time) * 1000, 2)

        result['http_code']       = http_code
        result['response_time_ms']= response_time

        # Check if status code matches expected
        if http_code == expected:
            result['is_up']  = True
            result['status'] = 'UP'
            result['message']= f"Responding normally (HTTP {http_code})"
        else:
            result['is_up']  = False
            result['status'] = 'DEGRADED'
            result['message']= f"Unexpected status code (HTTP {http_code}, expected {expected})"

    except urllib.error.HTTPError as e:
        end_time = time.time()
        result['http_code']       = e.code
        result['response_time_ms']= round((end_time - start_time) * 1000, 2)
        result['is_up']           = False
        result['status']          = 'DOWN'
        result['message']         = f"HTTP Error {e.code}: {e.reason}"

    except urllib.error.URLError as e:
        result['is_up']   = False
        result['status']  = 'DOWN'
        result['message'] = f"Connection failed: {str(e.reason)}"

    except socket.timeout:
        result['is_up']   = False
        result['status']  = 'DOWN'
        result['message'] = f"Request timed out after {timeout}s"

    except Exception as e:
        result['is_up']   = False
        result['status']  = 'DOWN'
        result['message'] = f"Unexpected error: {str(e)}"

    return result

# ── Print Result ─────────────────────────────
def print_result(result):
    name     = result['name']
    url      = result['url']
    status   = result['status']
    message  = result['message']
    rt       = result['response_time_ms']
    http     = result['http_code']

    # Status color and icon
    if status == 'UP':
        color = Colors.GREEN
        icon  = '[UP]'
    elif status == 'DEGRADED':
        color = Colors.YELLOW
        icon  = '[DEGRADED]'
    else:
        color = Colors.RED
        icon  = '[DOWN]'

    print(f"  Application  : {name}")
    print(f"  URL          : {url}")
    print(f"  Status       : {color}{icon}{Colors.RESET}")
    print(f"  HTTP Code    : {http if http else 'N/A'}")
    print(f"  Response Time: {rt}ms" if rt else "  Response Time: N/A")
    print(f"  Message      : {message}")

    # Alert if down
    if status == 'DOWN':
        print(f"  {Colors.RED}ALERT: {name} is DOWN! Immediate attention required!{Colors.RESET}")
        log("ALERT", f"{name} is DOWN — {message}")
    elif status == 'DEGRADED':
        print(f"  {Colors.YELLOW}WARNING: {name} is DEGRADED!{Colors.RESET}")
        log("WARNING", f"{name} is DEGRADED — {message}")
    else:
        log("INFO", f"{name} is UP — Response time: {rt}ms")

    print()

# ── Print Summary ────────────────────────────
def print_summary(results):
    total    = len(results)
    up       = sum(1 for r in results if r['status'] == 'UP')
    down     = sum(1 for r in results if r['status'] == 'DOWN')
    degraded = sum(1 for r in results if r['status'] == 'DEGRADED')

    print(f"{Colors.CYAN}── Summary ────────────────────────────{Colors.RESET}")
    print(f"  Total Applications : {total}")
    print(f"  {Colors.GREEN}UP                 : {up}{Colors.RESET}")
    print(f"  {Colors.YELLOW}DEGRADED           : {degraded}{Colors.RESET}")
    print(f"  {Colors.RED}DOWN               : {down}{Colors.RESET}")

    # Overall health
    if down == 0 and degraded == 0:
        print(f"\n  {Colors.GREEN}Overall Health: EXCELLENT — All systems operational{Colors.RESET}")
    elif down == 0:
        print(f"\n  {Colors.YELLOW}Overall Health: DEGRADED — Some issues detected{Colors.RESET}")
    else:
        print(f"\n  {Colors.RED}Overall Health: CRITICAL — {down} application(s) DOWN{Colors.RESET}")

    print(f"\n  Log file: {LOG_FILE}")
    print(f"{Colors.CYAN}{'='*50}{Colors.RESET}\n")

# ── Save JSON Report ─────────────────────────
def save_json_report(results):
    report = {
        "timestamp"   : datetime.datetime.now().isoformat(),
        "total"       : len(results),
        "up"          : sum(1 for r in results if r['status'] == 'UP'),
        "down"        : sum(1 for r in results if r['status'] == 'DOWN'),
        "degraded"    : sum(1 for r in results if r['status'] == 'DEGRADED'),
        "applications": results
    }
    report_file = "/tmp/app_health_report.json"
    with open(report_file, 'w') as f:
        json.dump(report, f, indent=2)
    print(f"  JSON report saved: {report_file}")

# ── Run Single Check ─────────────────────────
def run_check():
    print_header()
    log("INFO", "Health check started")

    results = []

    print(f"{Colors.CYAN}── Checking Applications ──────────────{Colors.RESET}\n")

    for app in APPLICATIONS:
        print(f"  Checking {app['name']}...")
        result = check_application(app)
        results.append(result)
        print_result(result)

    print_summary(results)
    save_json_report(results)

    log("INFO", "Health check completed")
    return results

# ── Continuous Monitor Mode ──────────────────
def run_continuous():
    print(f"{Colors.CYAN}Starting continuous monitoring (every {CHECK_INTERVAL}s){Colors.RESET}")
    print("Press Ctrl+C to stop\n")

    while True:
        try:
            results = run_check()
            print(f"Next check in {CHECK_INTERVAL} seconds...\n")
            time.sleep(CHECK_INTERVAL)
        except KeyboardInterrupt:
            print(f"\n{Colors.YELLOW}Monitoring stopped by user{Colors.RESET}")
            sys.exit(0)

# ── Main ─────────────────────────────────────
if __name__ == "__main__":
    # Check for continuous mode flag
    if len(sys.argv) > 1 and sys.argv[1] == '--continuous':
        run_continuous()
    else:
        results = run_check()
        # Exit with error code if any app is down
        if any(r['status'] == 'DOWN' for r in results):
            sys.exit(1)
        sys.exit(0)
