#!/bin/bash
# ============================================================
# 配置文件 - Linux系统运维工具箱
# ============================================================

# --- 模块开关 (true/false) ---
ENABLE_CPU_MONITOR=true
ENABLE_MEMORY_MONITOR=true
ENABLE_PROCESS_MONITOR=true
ENABLE_USER_TRACKER=true
ENABLE_FILE_SCANNER=true
ENABLE_LOG_ANALYZER=true

# --- 告警阈值 ---
CPU_ALARM_THRESHOLD=80          # CPU使用率告警阈值(%)
MEM_ALARM_THRESHOLD=80          # 内存使用率告警阈值(%)
SWAP_ALARM_THRESHOLD=50         # Swap使用率告警阈值(%)
DISK_ALARM_THRESHOLD=90         # 磁盘使用率告警阈值(%)
FAILED_LOGIN_THRESHOLD=5        # 登录失败次数告警阈值

# --- 文件扫描参数 ---
LARGE_FILE_SIZE="+100M"         # 大文件大小阈值
OLD_FILE_MTIME="+30"            # 旧文件天数
SCAN_DIRS=("/etc" "/bin" "/sbin")  # 安全扫描目录

# --- 日志分析参数 ---
LOG_ARCHIVE_DAYS=7              # 日志归档天数
LOG_DIR="/var/log"              # 日志目录
ARCHIVE_DIR="./archive"         # 归档保存目录
REPORT_DIR="./report"           # 报告输出目录

# --- 报告选项 ---
REPORT_TYPE="html"              # html 或 text
DAEMON_INTERVAL=60              # 守护进程运行间隔(秒)

# --- 颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- 日志配置 ---
LOG_FILE="./toolkit.log"
