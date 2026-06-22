#!/bin/bash
# ============================================================
# 公共函数库 - Linux系统运维工具箱
# 提供日志、颜色输出、错误处理等通用功能
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"

# --- 初始化目录 ---
init_dirs() {
    mkdir -p "$ARCHIVE_DIR" "$REPORT_DIR" 2>/dev/null
}

# --- 日志记录 ---
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
}

log_info()  { log "INFO" "$1"; echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { log "WARN" "$1"; echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { log "ERROR" "$1"; echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_debug() { log "DEBUG" "$1"; echo -e "${GRAY}[DEBUG]${NC} $1"; }
log_fatal() { log "FATAL" "$1"; echo -e "${RED}[FATAL]${NC} $1" >&2; exit 1; }

# --- 检查是否为 root 用户 ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "当前非root用户，部分功能可能受限"
        return 1
    fi
    return 0
}

# --- 安全执行命令（带超时） ---
safe_exec() {
    local timeout="$1"
    local cmd="$2"
    local desc="$3"

    log_debug "执行: $desc"
    timeout "$timeout" bash -c "$cmd" 2>/dev/null
    local rc=$?
    if [[ $rc -eq 124 ]]; then
        log_warn "命令超时: $desc"
    fi
    return $rc
}

# --- 打印分隔线 ---
print_separator() {
    local char="${1:-─}"
    local width="${2:-60}"
    printf "${GRAY}%${width}s${NC}\n" | tr ' ' "$char"
}

# --- 打印带边框的标题 ---
print_title() {
    local title="$1"
    local width="${2:-60}"
    local padding=$(( (width - ${#title} - 2) / 2 ))
    echo
    print_separator "═" "$width"
    printf "${CYAN}%s${NC}\n" "$(printf "%${padding}s" '') $title"
    print_separator "═" "$width"
    echo
}

# --- 打印彩色状态标签 ---
print_status() {
    local value="$1"
    local threshold_warn="$2"
    local threshold_crit="$3"

    if awk "BEGIN {exit !($value >= $threshold_crit)}" 2>/dev/null; then
        echo -e "${RED}${value}${NC}"
    elif awk "BEGIN {exit !($value >= $threshold_warn)}" 2>/dev/null; then
        echo -e "${YELLOW}${value}${NC}"
    else
        echo -e "${GREEN}${value}${NC}"
    fi
}

# --- 生成进度条 ---
progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local pct=0

    if [[ $total -gt 0 ]]; then
        pct=$(( current * 100 / total ))
    fi
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))

    printf "${CYAN}[${NC}"
    printf "${GREEN}%${filled}s${NC}" | tr ' ' '█'
    printf "${GRAY}%${empty}s${NC}" | tr ' ' '░'
    printf "${CYAN}]${NC} %3d%%" "$pct"
}

# --- 获取系统信息 ---
get_system_info() {
    local info
    info=$(cat <<EOF
系统信息:
  主机名:     $(hostname)
  操作系统:   $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)
  内核版本:   $(uname -r)
  架构:       $(uname -m)
  运行时间:   $(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | cut -d',' -f1)
  当前用户:   $(whoami)
  Shell:      $SHELL
EOF
)
    echo "$info"
}

# --- 检查依赖命令 ---
check_deps() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        log_error "请使用包管理器安装，例如: sudo apt-get install ${missing[*]}"
        return 1
    fi
    return 0
}

# --- 捕获中断信号 ---
cleanup_on_exit() {
    echo
    log_info "收到退出信号，正在清理..."
    # 清理临时文件
    rm -f /tmp/.toolkit_* 2>/dev/null
    log_info "退出工具箱"
    exit 0
}

trap cleanup_on_exit SIGINT SIGTERM

# --- 格式化字节数为可读格式 ---
format_bytes() {
    local bytes="$1"
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        awk "BEGIN {printf \"%.2fKB\", $bytes/1024}"
    elif [[ $bytes -lt 1073741824 ]]; then
        awk "BEGIN {printf \"%.2fMB\", $bytes/1048576}"
    else
        awk "BEGIN {printf \"%.2fGB\", $bytes/1073741824}"
    fi
}

# --- 获取当前时间戳 ---
get_timestamp() {
    date '+%Y%m%d_%H%M%S'
}

# --- 验证是否为数字 ---
is_number() {
    [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

# === 模块接口定义 ===

# 每个模块需要实现的接口函数：
#   module_run()     - 模块主入口
#   module_help()    - 显示帮助信息
#   module_name()    - 返回模块名称

# 模块注册表
declare -A MODULE_REGISTRY

register_module() {
    local name="$1"
    local desc="$2"
    MODULE_REGISTRY["$name"]="$desc"
}

list_modules() {
    echo -e "${CYAN}已注册模块:${NC}"
    for name in "${!MODULE_REGISTRY[@]}"; do
        printf "  ${GREEN}%-20s${NC} - %s\n" "$name" "${MODULE_REGISTRY[$name]}"
    done
}

# 初始化
init_dirs
log_info "公共函数库加载完成"
