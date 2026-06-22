#!/bin/bash
# ============================================================
# 模块一：系统性能监控仪 (System Performance Monitor)
# 功能: CPU监控、内存分析、进程排行
# ============================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

MODULE_NAME="system_monitor"
MODULE_DESC="系统性能监控仪 - CPU、内存、进程监控"

register_module "$MODULE_NAME" "$MODULE_DESC"

# --- 获取 CPU 使用率 ---
get_cpu_usage() {
    local cpu_id="${1:-整体}"
    local usage

    if [[ "$cpu_id" == "整体" ]]; then
        # 读取 /proc/stat 计算整体 CPU 使用率
        local cpu_line
        cpu_line=$(grep '^cpu ' /proc/stat 2>/dev/null)
        if [[ -z "$cpu_line" ]]; then
            log_error "无法读取 /proc/stat"
            return 1
        fi

        local idle total
        idle=$(echo "$cpu_line" | awk '{print $5}')
        total=$(echo "$cpu_line" | awk '{for(i=2;i<=NF;i++) sum+=$i} END {print sum}')

        # 第一次采样后等待
        sleep 0.5

        cpu_line=$(grep '^cpu ' /proc/stat 2>/dev/null)
        local idle2 total2
        idle2=$(echo "$cpu_line" | awk '{print $5}')
        total2=$(echo "$cpu_line" | awk '{for(i=2;i<=NF;i++) sum+=$i} END {print sum}')

        local diff_idle=$((idle2 - idle))
        local diff_total=$((total2 - total))

        if [[ $diff_total -gt 0 ]]; then
            usage=$(awk "BEGIN {printf \"%.1f\", (1 - $diff_idle/$diff_total) * 100}")
        else
            usage=0
        fi
    else
        # 获取特定核心使用率
        local core_line
        core_line=$(grep "^cpu$cpu_id" /proc/stat 2>/dev/null)
        if [[ -z "$core_line" ]]; then
            echo "0"
            return 1
        fi

        local idle total
        idle=$(echo "$core_line" | awk '{print $5}')
        total=$(echo "$core_line" | awk '{for(i=2;i<=NF;i++) sum+=$i} END {print sum}')

        sleep 0.5

        core_line=$(grep "^cpu$cpu_id" /proc/stat 2>/dev/null)
        local idle2 total2
        idle2=$(echo "$core_line" | awk '{print $5}')
        total2=$(echo "$core_line" | awk '{for(i=2;i<=NF;i++) sum+=$i} END {print sum}')

        local diff_idle=$((idle2 - idle))
        local diff_total=$((total2 - total))

        if [[ $diff_total -gt 0 ]]; then
            usage=$(awk "BEGIN {printf \"%.1f\", (1 - $diff_idle/$diff_total) * 100}")
        else
            usage=0
        fi
    fi

    echo "$usage"
}

# --- 获取 1分钟平均负载 ---
get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        awk '{print $1, $2, $3}' /proc/loadavg
    else
        uptime | awk -F'load average:' '{print $2}'
    fi
}

# --- 绘制 ASCII Art 负载趋势图 ---
draw_load_chart() {
    local samples=20
    local -a loads=()
    local i

    echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}         CPU 负载趋势图 (近${samples}秒)       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"

    # 采集样本
    for ((i=0; i<samples; i++)); do
        loads[$i]=$(get_cpu_usage "整体")
        sleep 0.3
    done

    # 找到最大值
    local max_val=1
    for val in "${loads[@]}"; do
        val_int=${val%.*}
        [[ $val_int -gt $max_val ]] && max_val=$val_int
    done
    # 向上取整到5的倍数
    max_val=$(( (max_val / 10 + 1) * 10 ))

    local rows=10
    local cols=$samples

    # 绘制柱状图（纵向）
    for ((r=rows; r>=0; r--)); do
        local threshold=$(( max_val * r / rows ))
        printf "${GRAY}%3d%%${NC} " "$threshold"
        for ((c=0; c<cols; c++)); do
            local val="${loads[$c]}"
            val_int=${val%.*}
            if [[ $val_int -ge $threshold ]]; then
                if [[ $val_int -ge $CPU_ALARM_THRESHOLD ]]; then
                    echo -ne "${RED}█${NC}"
                elif [[ $val_int -ge $(( CPU_ALARM_THRESHOLD * 2 / 3 )) ]]; then
                    echo -ne "${YELLOW}▓${NC}"
                else
                    echo -ne "${GREEN}▓${NC}"
                fi
            else
                echo -ne "${GRAY}·${NC}"
            fi
        done
        echo
    done

    # X 轴标签
    echo -ne "      "
    for ((c=0; c<cols; c+=5)); do
        printf "${GRAY}%-5s${NC}" "$((c+1))s"
    done
    echo
    echo -e "${GRAY}   └── (每0.5秒采样一次, 共${samples}秒)${NC}"

    # 平均CPU
    local sum=0
    for val in "${loads[@]}"; do
        sum=$(awk "BEGIN {print $sum + $val}")
    done
    local avg=$(awk "BEGIN {printf \"%.1f\", $sum / $samples}")
    echo -e "${CYAN}  平均CPU: ${NC}$(print_status "$avg" 50 80)${NC}"
}

# --- CPU 监控主函数 ---
cpu_monitor() {
    print_title "CPU 监控"

    # CPU 核心数
    local cpu_count
    cpu_count=$(nproc 2>/dev/null || grep -c '^processor' /proc/stat)

    # 获取整体使用率
    local cpu_usage
    cpu_usage=$(get_cpu_usage "整体")
    echo -e "  CPU 核心数: ${BOLD}${cpu_count}${NC} 核"
    echo -e "  整体使用率: $(print_status "$cpu_usage" 50 80)${NC}"

    # 各核心使用率
    if [[ $cpu_count -gt 1 ]]; then
        echo -e "\n${CYAN}  各核心使用率:${NC}"
        for ((i=0; i<cpu_count; i++)); do
            local core_usage
            core_usage=$(get_cpu_usage "$i")
            printf "  CPU %-3d : ${NC}" "$i"
            printf "$(print_status "$core_usage" 50 80)${NC}"
            # 微进度条
            local bar_len=20
            local filled
            filled=$(awk "BEGIN {printf \"%d\", $core_usage * $bar_len / 100}")
            printf " "
            printf "${GREEN}%${filled}s${NC}" | tr ' ' '█'
            printf "${GRAY}%$((bar_len - filled))s${NC}" | tr ' ' '░'
            echo
        done
    fi

    # 平均负载
    echo
    local load_avg
    load_avg=$(get_load_average)
    echo -e "  平均负载 (1/5/15分钟): ${BOLD}${load_avg}${NC}"
    local load_1min
    load_1min=$(echo "$load_avg" | awk '{print $1}')
    if awk "BEGIN {exit !($load_1min > $cpu_count * 0.7)}" 2>/dev/null; then
        echo -e "  ${YELLOW}  ⚠ 系统负载较高，建议检查异常进程${NC}"
    fi

    # 负载趋势图
    echo
    draw_load_chart
}

# --- 内存分析 ---
memory_monitor() {
    print_title "内存分析"

    if [[ ! -f /proc/meminfo ]]; then
        log_error "无法读取 /proc/meminfo"
        return 1
    fi

    # 读取内存信息
    local mem_total mem_available mem_free mem_buffers mem_cached
    mem_total=$(grep '^MemTotal:' /proc/meminfo | awk '{print $2}')
    mem_available=$(grep '^MemAvailable:' /proc/meminfo | awk '{print $2}')
    mem_free=$(grep '^MemFree:' /proc/meminfo | awk '{print $2}')
    mem_buffers=$(grep '^Buffers:' /proc/meminfo | awk '{print $2}')
    mem_cached=$(grep '^Cached:' /proc/meminfo | awk '{print $2}')

    # 计算使用率
    local mem_used_kb=$((mem_total - mem_available))
    local mem_usage
    mem_usage=$(awk "BEGIN {printf \"%.1f\", ($mem_used_kb / $mem_total) * 100}")

    # 转换为可读格式
    local mem_total_hr mem_used_hr mem_avail_hr
    mem_total_hr=$(format_bytes $((mem_total * 1024)))
    mem_used_hr=$(format_bytes $((mem_used_kb * 1024)))
    mem_avail_hr=$(format_bytes $((mem_available * 1024)))

    # 物理内存
    echo -e "  ${BOLD}物理内存 (RAM)${NC}"
    echo -e "    总量:  ${WHITE}$mem_total_hr${NC}"
    echo -e "    已用:  $(print_status "$mem_used_hr" "" "")"
    echo -e "    可用:  ${GREEN}$mem_avail_hr${NC}"
    echo -e "    Buffer: $(format_bytes $((mem_buffers * 1024)))"
    echo -e "    Cache:  $(format_bytes $((mem_cached * 1024)))"
    echo -e "    使用率: $(print_status "$mem_usage%" 50 80)"

    # 内存进度条
    local bar_len=40
    local filled
    filled=$(awk "BEGIN {printf \"%d\", $mem_usage * $bar_len / 100}")
    printf "  "
    for ((i=0; i<bar_len; i++)); do
        if [[ $i -lt $filled ]]; then
            if [[ $i -lt $(( bar_len * 50 / 100 )) ]]; then
                echo -ne "${GREEN}█${NC}"
            elif [[ $i -lt $(( bar_len * 80 / 100 )) ]]; then
                echo -ne "${YELLOW}█${NC}"
            else
                echo -ne "${RED}█${NC}"
            fi
        else
            echo -ne "${GRAY}░${NC}"
        fi
    done
    echo " ${mem_usage}%"

    # Swap 信息
    echo
    local swap_total swap_free
    swap_total=$(grep '^SwapTotal:' /proc/meminfo | awk '{print $2}')
    swap_free=$(grep '^SwapFree:' /proc/meminfo | awk '{print $2}')

    echo -e "  ${BOLD}Swap 空间${NC}"
    if [[ $swap_total -eq 0 ]]; then
        echo -e "    ${YELLOW}  ⚠ 未配置 Swap 空间${NC}"
    else
        local swap_used=$((swap_total - swap_free))
        local swap_usage
        swap_usage=$(awk "BEGIN {printf \"%.1f\", ($swap_used / $swap_total) * 100}")
        echo -e "    总量:  ${WHITE}$(format_bytes $((swap_total * 1024)))${NC}"
        echo -e "    已用:  $(print_status "$(format_bytes $((swap_used * 1024)))" "" "")"
        echo -e "    剩余:  ${GREEN}$(format_bytes $((swap_free * 1024)))${NC}"
        echo -e "    使用率: $(print_status "$swap_usage%" 30 50)"
    fi

    # 告警检查
    if awk "BEGIN {exit !($mem_usage >= $MEM_ALARM_THRESHOLD)}" 2>/dev/null; then
        echo
        echo -e "  ${RED}  ⚠ ⚠ ⚠ 内存使用率超过 ${MEM_ALARM_THRESHOLD}%！建议检查内存泄漏或扩展物理内存${NC}"
    fi
}

# --- 进程排行 ---
process_ranking() {
    print_title "进程资源排行 (Top 5)"

    # 检查 ps 命令
    if ! command -v ps &>/dev/null; then
        log_error "ps 命令不可用"
        return 1
    fi

    echo -e "${CYAN}  ┌──────┬────────────────────────────────┬────────┬────────────┬────────┐${NC}"
    echo -e "${CYAN}  │ PID  │ 进程名称                      │ CPU(%) │ 内存(%)    │ 状态   │${NC}"
    echo -e "${CYAN}  ├──────┼────────────────────────────────┼────────┼────────────┼────────┤${NC}"

    # 按 CPU 使用率排序 Top 5
    while IFS= read -r line; do
        local pid
        pid=$(echo "$line" | awk '{print $1}')
        local pname
        pname=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; printf "\n"}' | head -c 30)
        local cpu
        cpu=$(echo "$line" | awk '{print $3}')
        local mem
        mem=$(echo "$line" | awk '{print $4}')
        local stat
        stat=$(echo "$line" | awk '{print $8}')
        local rss
        rss=$(echo "$line" | awk '{print $6}')

        # 格式化进程名
        pname="${pname:0:30}"

        printf "  │ ${BOLD}%-5s${NC} │ %-30s │ " "$pid" "$pname"
        printf "$(print_status "${cpu}%" 10 50) │ "
        printf "$(print_status "${mem}%" 10 30) │ "
        printf "${WHITE}%-6s${NC} │\n" "$stat"
    done < <(ps aux --sort=-%cpu 2>/dev/null | head -n 6 | tail -n 5)

    echo -e "${CYAN}  ├──────┴────────────────────────────────┴────────┴────────────┴────────┤${NC}"
    echo -e "${CYAN}  │${NC}  按 ${YELLOW}CPU${NC} 排序                                             ${CYAN}│${NC}"
    echo -e "${CYAN}  ├──────────────────────────────────────────────────────────────────────┤${NC}"

    # 按内存使用率排序 Top 5
    while IFS= read -r line; do
        local pid
        pid=$(echo "$line" | awk '{print $1}')
        local pname
        pname=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; printf "\n"}' | head -c 30)
        local cpu
        cpu=$(echo "$line" | awk '{print $3}')
        local mem
        mem=$(echo "$line" | awk '{print $4}')
        local stat
        stat=$(echo "$line" | awk '{print $8}')

        pname="${pname:0:30}"

        printf "  │ ${BOLD}%-5s${NC} │ %-30s │ " "$pid" "$pname"
        printf "$(print_status "${cpu}%" 10 50) │ "
        printf "$(print_status "${mem}%" 10 30) │ "
        printf "${WHITE}%-6s${NC} │\n" "$stat"
    done < <(ps aux --sort=-%mem 2>/dev/null | head -n 6 | tail -n 5)

    echo -e "${CYAN}  └──────┴────────────────────────────────┴────────┴────────────┴────────┘${NC}"

    # 额外信息
    echo
    local total_procs
    total_procs=$(ps aux 2>/dev/null | wc -l)
    total_procs=$((total_procs - 1))
    local running_procs
    running_procs=$(ps -eo stat 2>/dev/null | grep -c '^R' 2>/dev/null)
    echo -e "  总进程数: ${BOLD}${total_procs}${NC}  |  运行中: ${GREEN}${running_procs}${NC}  |  休眠: ${GRAY}$((total_procs - running_procs))${NC}"
}

# --- 模块主入口 ---
module_run() {
    print_title "系统性能监控仪"
    echo -e "${BLUE}  监控时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    print_separator

    cpu_monitor
    print_separator
    memory_monitor
    print_separator
    process_ranking

    log_info "系统性能监控完成"
    echo
    echo -e "${GREEN}  ✔ 监控完成！${NC}"
    read -r -p "按回车键继续..."
}

# --- 模块帮助 ---
module_help() {
    cat <<EOF
模块: system_monitor - 系统性能监控仪

功能:
  CPU监控   - 实时获取整体及各核心使用率，1分钟平均负载，ASCII负载趋势图
  内存分析  - 区分物理内存与Swap空间，百分比计算，超阈值颜色告警
  进程排行  - 动态列出资源消耗Top 5进程(PID/名称/资源占比)

技术要点: /proc文件系统解析、awk数值计算、sleep循环控制

使用:
  ./module1_sysmonitor.sh        # 直接运行本模块
  ./module5_controller.sh        # 通过主控启动
EOF
}

# --- 直接运行时入口 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_run
fi
