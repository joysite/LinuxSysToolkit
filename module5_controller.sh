#!/bin/bash
# ============================================================
# 模块五：主控与调度中心 (Main Control & Scheduling Center)
# 功能: 交互界面、调度策略、报告生成
# ============================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

MODULE_NAME="controller"
MODULE_DESC="主控与调度中心 - 菜单界面、任务调度、报告生成"

register_module "$MODULE_NAME" "$MODULE_DESC"

# --- 脚本路径 ---
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE1="$BASE_DIR/module1_sysmonitor.sh"
MODULE2="$BASE_DIR/module2_user_tracker.sh"
MODULE3="$BASE_DIR/module3_file_scanner.sh"
MODULE4="$BASE_DIR/module4_log_analyzer.sh"

# --- 检查 dialog/whiptail 可用性 ---
check_tui_tool() {
    if command -v dialog &>/dev/null; then
        echo "dialog"
    elif command -v whiptail &>/dev/null; then
        echo "whiptail"
    else
        echo "none"
    fi
}

TUI_TOOL=$(check_tui_tool)

# ============================================================
# 交互界面
# ============================================================

# --- 显示 ASCII Art 标题 ---
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║     Linux 系统运维工具箱                              ║
  ║     Linux System Administration Toolkit              ║
  ║                                                      ║
  ║            ⚡  🛡️  📊  🔍  📋                        ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# --- 显示系统状态概览 ---
show_system_overview() {
    echo -e "${GREEN}  ┌─────────────── 系统概览 ───────────────┐${NC}"

    # 运行时间
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")
    printf "  │ ${BOLD}%-12s${NC} %-28s │\n" "运行时间:" "$uptime_str"

    # CPU 负载
    local load_str
    load_str=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    printf "  │ ${BOLD}%-12s${NC} %-28s │\n" "CPU负载:" "$load_str"

    # 内存使用
    if [[ -f /proc/meminfo ]]; then
        local mem_total mem_avail mem_pct
        mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
        mem_avail=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
        mem_pct=$(awk "BEGIN {printf \"%.1f%%\", (1 - $mem_avail / $mem_total) * 100}" 2>/dev/null)
        printf "  │ ${BOLD}%-12s${NC} %-28s │\n" "内存:" "$mem_pct"
    fi

    # 磁盘使用
    local disk_pct
    disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
    printf "  │ ${BOLD}%-12s${NC} %-28s │\n" "磁盘 (/):" "$disk_pct"

    # 登录用户
    local user_count
    user_count=$(who 2>/dev/null | wc -l)
    printf "  │ ${BOLD}%-12s${NC} %-28s │\n" "登录用户:" "$user_count"

    # 进程数
    local proc_count
    proc_count=$(ps aux 2>/dev/null | wc -l)
    printf "  │ ${BOLD}%-12s${NC} %-28s │\n" "进程数:" "$proc_count"

    echo -e "${GREEN}  └──────────────────────────────────────────┘${NC}"
}

# --- dialog/whiptail 菜单 ---
show_dialog_menu() {
    local tool="$TUI_TOOL"
    local choice

    if [[ "$tool" == "dialog" ]]; then
        choice=$(dialog --clear --title "Linux 系统运维工具箱" \
            --menu "请选择要执行的功能模块:" 20 60 10 \
            "1" "系统性能监控仪  - CPU/内存/进程" \
            "2" "用户活动追踪器  - 登录/审计/权限" \
            "3" "文件系统扫描仪  - 磁盘/大文件/安全" \
            "4" "日志分析引擎    - 追踪/归类/归档" \
            "5" "查看系统概览" \
            "6" "定时任务调度配置" \
            "7" "守护进程模式启动" \
            "8" "生成系统健康报告" \
            "9" "显示帮助信息" \
            "0" "退出工具箱" \
            2>&1 >/dev/tty)
        clear
    elif [[ "$tool" == "whiptail" ]]; then
        choice=$(whiptail --title "Linux 系统运维工具箱" \
            --menu "请选择要执行的功能模块:" 20 60 10 \
            "1" "系统性能监控仪  - CPU/内存/进程" \
            "2" "用户活动追踪器  - 登录/审计/权限" \
            "3" "文件系统扫描仪  - 磁盘/大文件/安全" \
            "4" "日志分析引擎    - 追踪/归类/归档" \
            "5" "查看系统概览" \
            "6" "定时任务调度配置" \
            "7" "守护进程模式启动" \
            "8" "生成系统健康报告" \
            "9" "显示帮助信息" \
            "0" "退出工具箱" \
            3>&1 1>&2 2>&3)
    fi

    echo "$choice"
}

# --- 终端文本菜单 ---
show_text_menu() {
    show_banner
    show_system_overview
    echo
    echo -e "${CYAN}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}           主 控 菜 单                    ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════╝${NC}"
    echo
    echo -e "  ${BOLD}1${NC}) ${GREEN}系统性能监控仪${NC}   - CPU/内存/进程监控"
    echo -e "  ${BOLD}2${NC}) ${GREEN}用户活动追踪器${NC}   - 登录监控/日志审计/权限检查"
    echo -e "  ${BOLD}3${NC}) ${GREEN}文件系统扫描仪${NC}   - 磁盘空间/大文件清理/安全扫描"
    echo -e "  ${BOLD}4${NC}) ${GREEN}日志分析引擎${NC}     - 实时追踪/归类统计/归档压缩"
    echo -e "  ${BOLD}5${NC}) ${YELLOW}系统概览${NC}         - 显示当前系统运行状态"
    echo
    echo -e "  ${BOLD}6${NC}) ${PURPLE}定时任务调度${NC}     - 配置 crontab 定时执行"
    echo -e "  ${BOLD}7${NC}) ${PURPLE}守护进程模式${NC}     - 后台持续运行监控"
    echo -e "  ${BOLD}8${NC}) ${PURPLE}生成健康报告${NC}     - 生成 HTML/PDF 日报/周报"
    echo -e "  ${BOLD}9${NC}) ${GRAY}帮助信息${NC}"
    echo
    echo -e "  ${RED} 0) 退出工具箱${NC}"
    echo
    read -r -p "  请输入选项 [0-9]: " choice
    echo "$choice"
}

# ============================================================
# 定时任务调度
# ============================================================

setup_crontab() {
    print_title "定时任务调度配置"

    echo -e "${CYAN}  当前用户 crontab 列表:${NC}"
    crontab -l 2>/dev/null | head -20 || echo -e "  ${GRAY}(无定时任务)${NC}"
    print_separator "─"

    echo -e "${CYAN}  设置定时执行:${NC}"
    echo -e "  ${BOLD}1${NC}) 每分钟执行系统监控"
    echo -e "  ${BOLD}2${NC}) 每5分钟执行系统监控"
    echo -e "  ${BOLD}3${NC}) 每小时执行系统监控"
    echo -e "  ${BOLD}4${NC}) 每天 8:00 执行并生成报告"
    echo -e "  ${BOLD}5${NC}) 每周一 8:00 生成周报"
    echo -e "  ${BOLD}6${NC}) 自定义 crontab 表达式"
    echo -e "  ${BOLD}7${NC}) 清除所有定时任务"
    echo -e "  ${BOLD}q${NC}) 返回"

    read -r -p "  选择: " cron_choice

    local cron_expr=""
    local cron_desc=""
    local cron_cmd="$BASE_DIR/module5_controller.sh --quiet report"

    case "$cron_choice" in
        1) cron_expr="* * * * *"; cron_desc="每分钟" ;;
        2) cron_expr="*/5 * * * *"; cron_desc="每5分钟" ;;
        3) cron_expr="0 * * * *"; cron_desc="每小时" ;;
        4) cron_expr="0 8 * * *"; cron_desc="每天 8:00" ;;
        5) cron_expr="0 8 * * 1"; cron_desc="每周一 8:00" ;;
        6)
            read -r -p "  输入 crontab 表达式 (分 时 日 月 周): " cron_expr
            cron_desc="自定义"
            ;;
        7)
            echo -e "  ${RED}  清除所有定时任务?${NC}"
            read -r -p "  确认? [y/N]: " del_confirm
            if [[ "$del_confirm" == "y" || "$del_confirm" == "Y" ]]; then
                crontab -r 2>/dev/null
                echo -e "  ${GREEN}✓ 已清除所有定时任务${NC}"
            fi
            return
            ;;
        q|Q) return ;;
        *) echo -e "  ${YELLOW}无效选项${NC}"; return ;;
    esac

    # 构建完整命令
    local full_cmd="$cron_expr cd $BASE_DIR && bash $cron_cmd >> $LOG_FILE 2>&1"

    echo
    echo -e "  计划: ${CYAN}$cron_desc${NC}"
    echo -e "  表达式: ${YELLOW}$cron_expr${NC}"
    echo -e "  命令: ${GRAY}$cron_cmd${NC}"
    read -r -p "  确认添加? [y/N]: " add_confirm

    if [[ "$add_confirm" == "y" || "$add_confirm" == "Y" ]]; then
        (crontab -l 2>/dev/null; echo "$full_cmd") | crontab -
        echo -e "  ${GREEN}✓ 定时任务已添加${NC}"
        crontab -l
    fi
}

# ============================================================
# 守护进程模式
# ============================================================

daemon_mode() {
    print_title "守护进程模式"

    local pid_file="/tmp/.toolkit_daemon.pid"

    # 检查是否已在运行
    if [[ -f "$pid_file" ]]; then
        local old_pid
        old_pid=$(cat "$pid_file")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠ 工具箱守护进程已在运行 (PID: $old_pid)${NC}"
            echo
            echo -e "  ${BOLD}1${NC}) 停止守护进程"
            echo -e "  ${BOLD}2${NC}) 查看状态"
            echo -e "  ${BOLD}q${NC}) 返回"
            read -r -p "  选择: " daemon_choice

            case "$daemon_choice" in
                1)
                    kill "$old_pid" 2>/dev/null
                    rm -f "$pid_file"
                    echo -e "  ${GREEN}✓ 守护进程已停止${NC}"
                    log_info "守护进程已停止 (PID: $old_pid)"
                    ;;
                2)
                    echo -e "  运行时间: $(ps -o etime -p "$old_pid" 2>/dev/null | tail -1 | xargs)"
                    echo -e "  内存占用: $(ps -o rss -p "$old_pid" 2>/dev/null | tail -1 | xargs) KB"
                    ;;
            esac
            return
        else
            rm -f "$pid_file"
        fi
    fi

    # 配置守护进程
    local interval="$DAEMON_INTERVAL"
    read -r -p "  监控间隔(秒, 默认 $DAEMON_INTERVAL): " input_interval
    [[ -n "$input_interval" ]] && interval="$input_interval"

    echo
    echo -e "${CYAN}  配置摘要:${NC}"
    echo -e "  间隔: ${BOLD}${interval}秒${NC}"
    echo -e "  日志: ${GRAY}$LOG_FILE${NC}"
    echo
    read -r -p "  启动守护进程? [y/N]: " daemon_start

    if [[ "$daemon_start" != "y" && "$daemon_start" != "Y" ]]; then
        return
    fi

    # 启动守护进程
    (
        # 双重 fork 脱离终端
        echo "$$" > "$pid_file"
        log_info "守护进程已启动 (PID: $$) 间隔: ${interval}s"

        while true; do
            {
                echo "========== 守护进程监控报告 $(date '+%Y-%m-%d %H:%M:%S') =========="
                echo "--- CPU ---"
                $MODULE1 --quiet 2>&1 | head -20
                echo "--- Memory ---"
                free -h
                echo "--- Disk ---"
                df -h /
                echo "--- Users ---"
                who
                echo "============================================"
            } >> "$LOG_FILE" 2>&1
            sleep "$interval"
        done
    ) &
    local daemon_pid=$!

    echo -e "  ${GREEN}✓ 守护进程已启动 (PID: $daemon_pid)${NC}"
    echo -e "  日志文件: ${GRAY}$LOG_FILE${NC}"
    echo -e "  使用 ${YELLOW}ps aux | grep toolkit${NC} 查看进程状态"
    log_info "守护进程已启动 (PID: $daemon_pid)"
}

# ============================================================
# 系统健康报告生成
# ============================================================

generate_report() {
    print_title "系统健康报告"

    local report_type="${1:-html}"
    local report_time=$(date '+%Y%m%d_%H%M%S')
    local report_file="$REPORT_DIR/system_report_${report_time}.${report_type}"

    echo -e "  报告类型: ${BOLD}${report_type^^}${NC}"
    echo -e "  输出文件: ${YELLOW}$report_file${NC}"
    echo

    # 收集数据
    echo -e "${CYAN}  正在采集系统数据...${NC}"

    local hostname=$(hostname)
    local os_info=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || uname -s)
    local kernel=$(uname -r)
    local uptime_str=$(uptime -p 2>/dev/null || uptime | awk -F'up' '{print $2}' | cut -d',' -f1)
    local date_str=$(date '+%Y-%m-%d %H:%M:%S')
    local users=$(who | wc -l)

    # CPU 使用率
    local cpu_usage=$(grep '^cpu ' /proc/stat | awk '{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; printf "%.1f", (1-idle/total)*100}')
    sleep 0.3
    local cpu_usage2=$(grep '^cpu ' /proc/stat | awk '{idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; printf "%.1f", (1-idle/total)*100}')
    local cpu_final=$(awk "BEGIN {printf \"%.1f\", ($cpu_usage + $cpu_usage2) / 2}")

    # 内存
    local mem_total=$(free -h 2>/dev/null | grep "^Mem:" | awk '{print $2}')
    local mem_used=$(free -h 2>/dev/null | grep "^Mem:" | awk '{print $3}')
    local mem_pct=$(free 2>/dev/null | grep "^Mem:" | awk '{printf "%.1f", $3/$2 * 100}')

    # 磁盘
    local disk_total=$(df -h / 2>/dev/null | tail -1 | awk '{print $2}')
    local disk_used=$(df -h / 2>/dev/null | tail -1 | awk '{print $3}')
    local disk_pct=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')

    # 计算健康评分
    local health_score=100
    # CPU 扣分
    if awk "BEGIN {exit !($cpu_final > 80)}" 2>/dev/null; then health_score=$((health_score - 20))
    elif awk "BEGIN {exit !($cpu_final > 60)}" 2>/dev/null; then health_score=$((health_score - 10)); fi
    # 内存扣分
    if awk "BEGIN {exit !($mem_pct > 80)}" 2>/dev/null; then health_score=$((health_score - 20))
    elif awk "BEGIN {exit !($mem_pct > 60)}" 2>/dev/null; then health_score=$((health_score - 10)); fi
    # 磁盘扣分
    local disk_pct_num=${disk_pct%\%}
    if [[ $disk_pct_num -ge 90 ]]; then health_score=$((health_score - 20))
    elif [[ $disk_pct_num -ge 70 ]]; then health_score=$((health_score - 10)); fi

    # 健康等级
    local health_level="优"
    local health_color="#4CAF50"
    if [[ $health_score -lt 60 ]]; then
        health_level="差"; health_color="#f44336"
    elif [[ $health_score -lt 80 ]]; then
        health_level="中"; health_color="#FF9800"
    fi

    # --- 生成 HTML 报告 ---
    if [[ "$report_type" == "html" ]]; then
        cat > "$report_file" << HTMLREPORT
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>系统健康报告 - $hostname</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', 'PingFang SC', Roboto, sans-serif; background: #f0f2f5; color: #333; padding: 20px; }
        .container { max-width: 900px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border-radius: 15px; padding: 30px; margin-bottom: 20px; text-align: center; }
        .header h1 { font-size: 28px; margin-bottom: 5px; }
        .header .subtitle { opacity: 0.8; font-size: 14px; }
        .score-card { background: white; border-radius: 15px; padding: 25px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center; }
        .score-circle { display: inline-block; width: 120px; height: 120px; border-radius: 50%; background: conic-gradient($health_color 0% ${health_score}%, #e0e0e0 ${health_score}% 100%); margin: 15px; position: relative; }
        .score-circle::after { content: ''; position: absolute; top: 10px; left: 10px; width: 100px; height: 100px; border-radius: 50%; background: white; }
        .score-value { position: relative; z-index: 1; top: 30px; font-size: 36px; font-weight: bold; color: $health_color; }
        .score-label { color: #666; margin-top: 5px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; margin-bottom: 20px; }
        .card { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .card h3 { margin-bottom: 15px; color: #555; border-bottom: 2px solid #f0f2f5; padding-bottom: 10px; }
        .metric { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #f5f5f5; }
        .metric .label { color: #888; }
        .metric .value { font-weight: bold; }
        .good { color: #4CAF50; }
        .warn { color: #FF9800; }
        .danger { color: #f44336; }
        .detail { background: white; border-radius: 12px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .detail h3 { margin-bottom: 15px; color: #555; border-bottom: 2px solid #f0f2f5; padding-bottom: 10px; }
        table { width: 100%; border-collapse: collapse; }
        table th, table td { padding: 10px; text-align: left; border-bottom: 1px solid #f0f2f5; }
        table th { background: #f8f9fa; color: #666; font-weight: 600; }
        .footer { text-align: center; color: #999; font-size: 12px; margin-top: 20px; }
        .badge { display: inline-block; padding: 3px 12px; border-radius: 12px; color: white; font-size: 12px; }
        .badge.good { background: #4CAF50; }
        .badge.warn { background: #FF9800; }
        .badge.danger { background: #f44336; }
        @media (max-width: 600px) { .grid { grid-template-columns: 1fr; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🖥️ 系统健康报告</h1>
            <div class="subtitle">$hostname | 生成时间: $date_str</div>
        </div>

        <div class="score-card">
            <h2>系统健康评分</h2>
            <div class="score-circle">
                <div class="score-value">$health_score</div>
            </div>
            <div style="margin-top: 5px;">
                <span class="badge $( [ $health_score -ge 80 ] && echo 'good' || [ $health_score -ge 60 ] && echo 'warn' || echo 'danger' )">$health_level</span>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <h3>💻 系统信息</h3>
                <div class="metric"><span class="label">主机名</span><span class="value">$hostname</span></div>
                <div class="metric"><span class="label">操作系统</span><span class="value">$os_info</span></div>
                <div class="metric"><span class="label">内核版本</span><span class="value">$kernel</span></div>
                <div class="metric"><span class="label">运行时间</span><span class="value">$uptime_str</span></div>
                <div class="metric"><span class="label">在线用户</span><span class="value">$users 人</span></div>
            </div>

            <div class="card">
                <h3>📊 资源使用</h3>
                <div class="metric">
                    <span class="label">CPU 使用率</span>
                    <span class="value $( [ $cpu_final -ge 80 ] && echo 'danger' || [ $cpu_final -ge 60 ] && echo 'warn' || echo 'good' )">${cpu_final}%</span>
                </div>
                <div class="metric">
                    <span class="label">内存使用</span>
                    <span class="value $( [ $mem_pct -ge 80 ] && echo 'danger' || [ $mem_pct -ge 60 ] && echo 'warn' || echo 'good' )">${mem_used} / ${mem_total} (${mem_pct}%)</span>
                </div>
                <div class="metric">
                    <span class="label">磁盘使用 (/dev)</span>
                    <span class="value $( [ $disk_pct_num -ge 90 ] && echo 'danger' || [ $disk_pct_num -ge 70 ] && echo 'warn' || echo 'good' )">${disk_used} / ${disk_total} (${disk_pct})</span>
                </div>
            </div>
        </div>

        <div class="detail">
            <h3>📋 健康检查明细</h3>
            <table>
                <tr><th>检查项</th><th>状态</th><th>详情</th></tr>
                <tr>
                    <td>CPU 负载</td>
                    <td><span class="badge $( [ $cpu_final -ge 80 ] && echo 'danger' || [ $cpu_final -ge 60 ] && echo 'warn' || echo 'good' )">$( [ $cpu_final -ge 80 ] && echo '异常' || [ $cpu_final -ge 60 ] && echo '警告' || echo '正常' )</span></td>
                    <td>当前 ${cpu_final}%</td>
                </tr>
                <tr>
                    <td>内存使用</td>
                    <td><span class="badge $( [ $mem_pct -ge 80 ] && echo 'danger' || [ $mem_pct -ge 60 ] && echo 'warn' || echo 'good' )">$( [ $mem_pct -ge 80 ] && echo '异常' || [ $mem_pct -ge 60 ] && echo '警告' || echo '正常' )</span></td>
                    <td>已用 ${mem_used} / 总共 ${mem_total}</td>
                </tr>
                <tr>
                    <td>磁盘空间</td>
                    <td><span class="badge $( [ $disk_pct_num -ge 90 ] && echo 'danger' || [ $disk_pct_num -ge 70 ] && echo 'warn' || echo 'good' )">$( [ $disk_pct_num -ge 90 ] && echo '异常' || [ $disk_pct_num -ge 70 ] && echo '警告' || echo '正常' )</span></td>
                    <td>根分区使用 ${disk_pct}</td>
                </tr>
            </table>
        </div>

        <div class="detail">
            <h3>📈 Top 5 进程 (按 CPU)</h3>
            <table>
                <tr><th>PID</th><th>进程名</th><th>CPU%</th><th>内存%</th></tr>
HTMLREPORT

        # 添加进程列表
        ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | while IFS= read -r line; do
            local pid=$(echo "$line" | awk '{print $2}')
            local pname=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}' | head -c 30)
            local cpu=$(echo "$line" | awk '{print $3}')
            local mem=$(echo "$line" | awk '{print $4}')
            cat >> "$report_file" << HTMLREPORT
                <tr><td>$pid</td><td>${pname}</td><td>$cpu</td><td>$mem</td></tr>
HTMLREPORT
        done

        # 关闭 HTML
        cat >> "$report_file" << HTMLREPORT
            </table>
        </div>

        <div class="footer">
            <p>由 Linux 系统运维工具箱自动生成 | $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
    </div>
</body>
</html>
HTMLREPORT

        echo -e "  ${GREEN}✓ HTML 报告已生成: ${report_file}${NC}"

    # 文本报告
    else
        {
            echo "=============================================="
            echo "  系统健康报告"
            echo "  主机: $hostname"
            echo "  时间: $date_str"
            echo "=============================================="
            echo
            echo "【系统信息】"
            echo "  操作系统: $os_info"
            echo "  内核: $kernel"
            echo "  运行时间: $uptime_str"
            echo "  在线用户: $users"
            echo
            echo "【资源使用】"
            echo "  CPU: ${cpu_final}%  (健康评分贡献: $([ $cpu_final -ge 80 ] && echo '扣20分' || [ $cpu_final -ge 60 ] && echo '扣10分' || echo '正常')"
            echo "  内存: ${mem_used}/${mem_total} (${mem_pct}%)"
            echo "  磁盘: ${disk_used}/${disk_total} (${disk_pct})"
            echo
            echo "【健康评分】$health_score 分 ($health_level)"
            echo "=============================================="
            echo "  Top 5 CPU 进程:"
            ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | awk '{printf "  %-8s %-30s %-6s %-6s\n", $2, $11, $3"%", $4"%"}'
            echo "=============================================="
            echo "  由 Linux 系统运维工具箱自动生成"
            date
        } > "$report_file"
        echo -e "  ${GREEN}✓ 文本报告已生成: ${report_file}${NC}"
    fi

    log_info "系统健康报告已生成: $report_file"
    echo
    ls -lh "$report_file"
    echo
    read -r -p "  按回车键继续..."
}

# ============================================================
# 执行模块
# ============================================================

run_module() {
    local module_num="$1"
    local module_args="${2:-}"

    case "$module_num" in
        1)
            echo
            echo -e "${GREEN}  ▶ 启动系统性能监控仪...${NC}"
            source "$MODULE1"
            module_run
            ;;
        2)
            echo
            echo -e "${GREEN}  ▶ 启动用户活动追踪器...${NC}"
            source "$MODULE2"
            module_run
            ;;
        3)
            echo
            echo -e "${GREEN}  ▶ 启动文件系统扫描仪...${NC}"
            source "$MODULE3"
            ARGV="$module_args" module_run
            ;;
        4)
            echo
            echo -e "${GREEN}  ▶ 启动日志分析引擎...${NC}"
            source "$MODULE4"
            module_run
            ;;
        5)
            show_banner
            show_system_overview
            echo
            read -r -p "  按回车键返回..."
            ;;
        6)
            setup_crontab
            ;;
        7)
            daemon_mode
            ;;
        8)
            local rtype="html"
            echo
            echo -e "  报告格式:"
            echo -e "  ${BOLD}1${NC}) HTML (默认，推荐)"
            echo -e "  ${BOLD}2${NC}) 文本"
            read -r -p "  选择 [1/2]: " format_choice
            [[ "$format_choice" == "2" ]] && rtype="text"
            generate_report "$rtype"
            ;;
        9)
            show_help
            read -r -p "  按回车键返回..."
            ;;
        0)
            echo
            echo -e "${GREEN} 感谢使用 Linux 系统运维工具箱！${NC}"
            log_info "用户退出工具箱"
            exit 0
            ;;
        *)
            echo -e "  ${RED}无效选项: $module_num${NC}"
            read -r -p "  按回车键返回..."
            ;;
    esac
}

# ============================================================
# 帮助信息
# ============================================================

show_help() {
    print_title "帮助信息"
    cat <<EOF
${CYAN}Linux 系统运维工具箱${NC}
版本: 1.0.0

${BOLD}模块说明:${NC}
  1. 系统性能监控仪  - CPU使用率/负载趋势图/内存分析/进程排行
  2. 用户活动追踪器  - 当前登录/登录历史/失败审计/权限检查
  3. 文件系统扫描仪  - 磁盘空间/大文件查找/SUID检查/安全扫描
  4. 日志分析引擎    - 实时追踪/归类统计/归档压缩
  5. 系统概览        - 当前系统运行状态总览
  6. 定时任务调度    - 配置 crontab 定时执行监控任务
  7. 守护进程模式    - 后台持续运行监控
  8. 生成健康报告    - 生成 HTML 格式系统健康报告

${BOLD}命令行选项:${NC}
  --help         显示此帮助
  --menu         显示交互式菜单 (默认)
  --quiet        安静模式，直接执行所有模块并退出
  --module N     只运行指定模块 (1-4)
  --daemon       以守护进程模式启动
  --cron         配置定时任务
  --report [type] 生成健康报告 (html/text)

${BOLD}使用示例:${NC}
  ./module5_controller.sh           # 交互式菜单
  ./module5_controller.sh --daemon  # 守护进程模式
  ./module5_controller.sh --report  # 生成 HTML 报告

${BOLD}系统要求:${NC}
  - Linux 操作系统
  - Bash 4.0+
  - 常用命令: ps, df, free, who, last, grep, awk, sed

${BOLD}注意事项:${NC}
  - 部分功能 (如用户审计) 需要 root 权限
  - 日志分析模块涉及 /var/log 目录需要相应读取权限
  - 守护进程会持续运行，请合理设置监控间隔
EOF
}

# ============================================================
# 主入口
# ============================================================

module_run() {
    # 解析命令行参数
    if [[ $# -gt 0 ]]; then
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --quiet)
                echo -e "${GREEN}▶ 安静模式: 依次执行所有模块${NC}"
                for m in 1 2 3 4; do
                    echo
                    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
                    echo -e "${CYAN}  模块 $m${NC}"
                    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
                    run_module "$m"
                done
                generate_report "html"
                echo
                echo -e "${GREEN}✔ 所有模块执行完成${NC}"
                exit 0
                ;;
            --module)
                run_module "$2" "$3"
                exit 0
                ;;
            --daemon)
                daemon_mode
                exit 0
                ;;
            --cron)
                setup_crontab
                exit 0
                ;;
            --report)
                generate_report "${2:-html}"
                exit 0
                ;;
            --menu)
                # 继续进入主菜单
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    fi

    # 交互式主循环
    while true; do
        if [[ "$TUI_TOOL" != "none" ]]; then
            # 使用 dialog/whiptail 菜单
            local tui_choice
            tui_choice=$(show_dialog_menu)
            if [[ -z "$tui_choice" ]]; then
                # 用户取消（按ESC）
                echo
                echo -e "${GREEN}感谢使用 Linux 系统运维工具箱！${NC}"
                exit 0
            fi
            run_module "$tui_choice"
        else
            # 使用文本菜单
            local choice
            choice=$(show_text_menu)
            run_module "$choice"
        fi
    done
}

# --- 模块帮助 ---
module_help() {
    show_help
}

# --- 直接运行时入口 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_run "$@"
fi
