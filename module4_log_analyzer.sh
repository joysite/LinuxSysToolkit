#!/bin/bash
# ============================================================
# 模块四：日志分析引擎 (Log Analysis Engine)
# 功能: 实时追踪、智能归类、归档压缩
# ============================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

MODULE_NAME="log_analyzer"
MODULE_DESC="日志分析引擎 - 实时日志追踪、智能归类、归档压缩"

register_module "$MODULE_NAME" "$MODULE_DESC"

# --- 信号捕获（实现优雅退出） ---
TRACKING_PID=""
cleanup_tracking() {
    if [[ -n "$TRACKING_PID" ]] && kill -0 "$TRACKING_PID" 2>/dev/null; then
        kill "$TRACKING_PID" 2>/dev/null
        wait "$TRACKING_PID" 2>/dev/null
    fi
    echo
    log_info "日志追踪已停止"
    rm -f /tmp/.toolkit_log_tail 2>/dev/null
}

# --- 实时日志追踪 ---
real_time_track() {
    print_title "实时日志追踪"

    # 选择日志文件
    local -a log_files=()
    local idx=1

    echo -e "${CYAN}  可用日志文件:${NC}"
    echo -e "  ${BOLD}${idx})${NC} /var/log/syslog"
    ((idx++))
    echo -e "  ${BOLD}${idx})${NC} /var/log/auth.log"
    ((idx++))
    echo -e "  ${BOLD}${idx})${NC} /var/log/kern.log"
    ((idx++))
    echo -e "  ${BOLD}${idx})${NC} /var/log/dmesg"
    ((idx++))
    echo -e "  ${BOLD}${idx})${NC} /var/log/bootstrap.log"
    ((idx++))
    echo -e "  ${BOLD}${idx})${NC} 自定义路径"
    ((idx++))

    read -r -p "  选择日志文件 [1-${idx}]: " log_choice

    local log_path=""
    case "$log_choice" in
        1) log_path="/var/log/syslog" ;;
        2) log_path="/var/log/auth.log" ;;
        3) log_path="/var/log/kern.log" ;;
        4) log_path="/var/log/dmesg" ;;
        5) log_path="/var/log/bootstrap.log" ;;
        6)
            read -r -p "  输入日志文件路径: " custom_path
            log_path="$custom_path"
            ;;
        *)  log_path="/var/log/syslog" ;;
    esac

    if [[ ! -f "$log_path" ]]; then
        log_error "日志文件不存在: $log_path"
        read -r -p "按回车键返回..."
        return 1
    fi

    if [[ ! -r "$log_path" ]]; then
        log_error "无权限读取: $log_path"
        read -r -p "按回车键返回..."
        return 1
    fi

    # 选择过滤关键词
    echo
    echo -e "${CYAN}  过滤选项:${NC}"
    echo -e "  ${BOLD}1${NC}) 显示所有日志"
    echo -e "  ${BOLD}2${NC}) 过滤 ERROR/错误"
    echo -e "  ${BOLD}3${NC}) 过滤 WARN/警告"
    echo -e "  ${BOLD}4${NC}) 过滤 SSH 相关"
    echo -e "  ${BOLD}5${NC}) 自定义关键词"
    read -r -p "  选择过滤器 [1-5]: " filter_choice

    local filter_pattern=""
    case "$filter_choice" in
        2) filter_pattern="ERROR|error|Failed|failure" ;;
        3) filter_pattern="WARN|warn|warning" ;;
        4) filter_pattern="sshd|ssh|SSH" ;;
        5) read -r -p "  输入过滤关键词: " custom_filter
           filter_pattern="$custom_filter" ;;
    esac

    echo
    echo -e "${GREEN}  ╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}  ║  实时日志追踪已启动                         ║${NC}"
    echo -e "${GREEN}  ║  文件: $log_path${NC}"
    [[ -n "$filter_pattern" ]] && echo -e "${GREEN}  ║  过滤: $filter_pattern  ${NC}"
    echo -e "${GREEN}  ║  按 Ctrl+C 停止追踪                       ║${NC}"
    echo -e "${GREEN}  ╚══════════════════════════════════════════╝${NC}"
    echo

    # 设置信号捕获
    trap 'cleanup_tracking; return 0' SIGINT SIGTERM

    # 使用 tail -f 实时追踪
    if [[ -n "$filter_pattern" ]]; then
        # 带过滤的实时追踪
        tail -f "$log_path" 2>/dev/null | while IFS= read -r line; do
            if echo "$line" | grep -E -- "$filter_pattern" &>/dev/null; then
                local timestamp
                timestamp=$(echo "$line" | awk '{print $1, $2, $3}')

                # 根据关键词着色
                if echo "$line" | grep -qi "error\|failed\|failure\|invalid"; then
                    echo -e "${RED}$line${NC}"
                elif echo "$line" | grep -qi "warn"; then
                    echo -e "${YELLOW}$line${NC}"
                else
                    echo -e "${GRAY}$line${NC}"
                fi
            fi
        done
    else
        # 显示所有日志
        tail -f "$log_path" 2>/dev/null
    fi

    # 清理
    trap - SIGINT SIGTERM
}

# --- 日志智能归类 ---
classify_logs() {
    print_title "日志智能归类分析"

    local log_dir="${1:-/var/log}"

    # 寻找主流日志文件
    local -a log_sources=()

    if [[ -f "$log_dir/syslog" ]]; then
        log_sources+=("$log_dir/syslog")
    elif [[ -f "$log_dir/messages" ]]; then
        log_sources+=("$log_dir/messages")
    fi

    if [[ -f "$log_dir/auth.log" ]]; then
        log_sources+=("$log_dir/auth.log")
    elif [[ -f "$log_dir/secure" ]]; then
        log_sources+=("$log_dir/secure")
    fi

    if [[ ${#log_sources[@]} -eq 0 ]]; then
        log_warn "在 $log_dir 中未找到可分析的日志文件"
        echo -e "  ${YELLOW}  提示: 可使用 journalctl 查看系统日志${NC}"

        if command -v journalctl &>/dev/null; then
            echo
            echo -e "${CYAN}  尝试从 journalctl 获取日志统计:${NC}"
            journalctl --since "1 hour ago" -p err 2>/dev/null | tail -20
        fi
        read -r -p "按回车键返回..."
        return 1
    fi

    # 检查日志大小
    local total_size=0
    for log in "${log_sources[@]}"; do
        local size
        size=$(stat --format="%s" "$log" 2>/dev/null || echo "0")
        total_size=$((total_size + size))
    done

    echo -e "  分析日志文件数: ${BOLD}${#log_sources[@]}${NC}"
    echo -e "  日志总量: ${YELLOW}$(format_bytes "$total_size")${NC}"
    print_separator "─"

    # 按服务名归类
    echo -e "${CYAN}  1. 按服务名归类统计:${NC}"
    print_separator "─"
    printf "${CYAN}  %-25s %-15s %s${NC}\n" "服务名/标签" "条目数" "主要级别"
    print_separator "─"

    declare -A service_count
    declare -A service_level

    for log in "${log_sources[@]}"; do
        # 提取标签（第一个字段后带:的）
        while IFS= read -r line; do
            local svc
            svc=$(echo "$line" | grep -oP '\b\w+(?=\[\d+\])' | head -1)
            [[ -z "$svc" ]] && svc=$(echo "$line" | awk '{for(i=5;i<=NF;i++) if($i ~ /:/) {print $i; break}}' | tr -d ':')
            [[ -z "$svc" ]] && svc="unknown"

            service_count["$svc"]=$((service_count["$svc"] + 1))

            local level="INFO"
            if echo "$line" | grep -qi "error\|failed"; then
                level="ERROR"
            elif echo "$line" | grep -qi "warn"; then
                level="WARN"
            fi
            service_level["$svc"]="$level"

        done < <(tail -1000 "$log" 2>/dev/null)
    done

    # 排序并显示 Top 10 服务
    for svc in "${!service_count[@]}"; do
        echo "${service_count[$svc]} $svc ${service_level[$svc]}"
    done | sort -rn | head -10 | while read count svc level; do
        local level_color
        case "$level" in
            ERROR) level_color="${RED}$level${NC}" ;;
            WARN)  level_color="${YELLOW}$level${NC}" ;;
            *)     level_color="${GREEN}$level${NC}" ;;
        esac
        printf "  %-25s ${WHITE}%-10d${NC} %b\n" "$svc" "$count" "$level_color"
    done

    # 按错误级别统计
    echo
    echo -e "${CYAN}  2. 按错误级别统计:${NC}"
    print_separator "─"

    local err_count=0
    local warn_count=0
    local info_count=0

    for log in "${log_sources[@]}"; do
        local lines
        lines=$(wc -l < "$log" 2>/dev/null)
        local err warn
        err=$(grep -ci "error\|failed\|failure\|critical" "$log" 2>/dev/null)
        warn=$(grep -ci "warn" "$log" 2>/dev/null)
        err_count=$((err_count + err))
        warn_count=$((warn_count + warn))
        info_count=$((info_count + lines - err - warn))
    done

    local total_entries=$((err_count + warn_count + info_count))

    echo -e "  ${RED}  ERROR: ${err_count}${NC} $(progress_bar "$err_count" "$total_entries")"
    echo -e "  ${YELLOW}  WARN:  ${warn_count}${NC} $(progress_bar "$warn_count" "$total_entries")"
    echo -e "  ${GREEN}  INFO:  ${info_count}${NC} $(progress_bar "$info_count" "$total_entries")"

    # 错误详情（最近20条 ERROR）
    if [[ $err_count -gt 0 ]]; then
        echo
        echo -e "${RED}  最近 ERROR 记录 (Top 15):${NC}"
        print_separator "─"
        for log in "${log_sources[@]}"; do
            grep -in "error\|failed\|failure\|critical" "$log" 2>/dev/null | tail -15 | while IFS= read -r line; do
                echo -e "  ${RED}${line:0:120}${NC}"
            done
        done | head -15
    fi

    # 时间戳分布
    echo
    echo -e "${CYAN}  3. 时间分布 (最近20分钟日志量):${NC}"
    print_separator "─"

    local recent_count=0
    for log in "${log_sources[@]}"; do
        local rc
        rc=$(grep -c "$(date '+%b %e %H'):" "$log" 2>/dev/null)
        recent_count=$((recent_count + rc))
    done
    echo -e "  当前小时日志数: ${BOLD}${recent_count}${NC} 条"

    # 日志增长速度监控
    print_separator "─"
    if [[ ${#log_sources[@]} -gt 0 ]]; then
        echo -e "${CYAN}  日志文件大小变化:${NC}"
        for log in "${log_sources[@]}"; do
            local current_size prev_size growth
            current_size=$(stat --format="%s" "$log" 2>/dev/null || echo "0")
            echo -e "  $(basename "$log"): $(format_bytes "$current_size")"
        done
    fi
}

# --- 日志归档压缩 ---
archive_logs() {
    print_title "日志归档与压缩"

    local source_dir="${1:-$LOG_DIR}"
    local archive_dir="${2:-$ARCHIVE_DIR}"
    local days_old="${3:-$LOG_ARCHIVE_DAYS}"
    local suffix

    # 处理传入参数
    if [[ -n "$ARGV" ]]; then
        local args=($ARGV)
        [[ -n "${args[0]}" ]] && source_dir="${args[0]}"
        [[ -n "${args[1]}" ]] && archive_dir="${args[1]}"
        [[ -n "${args[2]}" ]] && days_old="${args[2]}"
    fi

    mkdir -p "$archive_dir" 2>/dev/null

    echo -e "  源目录: ${CYAN}$source_dir${NC}"
    echo -e "  归档目录: ${YELLOW}$archive_dir${NC}"
    echo -e "  归档阈值: ${BOLD}${days_old}天${NC} 前的日志"
    print_separator "─"

    # 查找需要归档的日志文件
    local tmp_archive_list
    tmp_archive_list=$(mktemp /tmp/.toolkit_archive_list.XXXXXX)

    find "$source_dir" -maxdepth 2 -name "*.log" -o -name "*.log.*" -o -name "*.gz" 2>/dev/null | \
        while IFS= read -r f; do
            if [[ -f "$f" ]] && [[ ! "$f" =~ \.tar\.gz$ ]]; then
                local mtime
                mtime=$(stat --format="%Y" "$f" 2>/dev/null || echo "0")
                local now
                now=$(date +%s)
                local age_days=$(( (now - mtime) / 86400 ))
                if [[ $age_days -ge $days_old ]]; then
                    echo "$f"
                fi
            fi
        done > "$tmp_archive_list"

    local archive_count
    archive_count=$(wc -l < "$tmp_archive_list")

    if [[ $archive_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ 没有需要归档的日志文件${NC}"
        rm -f "$tmp_archive_list"
        return
    fi

    echo -e "  找到 ${YELLOW}${archive_count}${NC} 个需要归档的日志文件"

    # 预览
    echo
    echo -e "${CYAN}  待归档文件:${NC}"
    awk '{print "    " $0}' "$tmp_archive_list" | head -20
    if [[ $archive_count -gt 20 ]]; then
        echo -e "    ${GRAY}... 还有 $((archive_count - 20)) 个文件${NC}"
    fi

    # 总大小
    local total_archive_size=0
    while IFS= read -r f; do
        local fsize
        fsize=$(stat --format="%s" "$f" 2>/dev/null || echo "0")
        total_archive_size=$((total_archive_size + fsize))
    done < "$tmp_archive_list"
    echo -e "  待归档总大小: ${YELLOW}$(format_bytes "$total_archive_size")${NC}"

    echo
    read -r -p "  确认归档? [y/N]: " archive_confirm

    if [[ "$archive_confirm" != "y" && "$archive_confirm" != "Y" ]]; then
        echo -e "  ${GRAY}已取消归档${NC}"
        rm -f "$tmp_archive_list"
        return
    fi

    # 执行归档
    echo
    local archive_name="logs_archive_$(get_timestamp)"
    local archive_path="$archive_dir/${archive_name}.tar.gz"

    echo -e "${CYAN}  正在压缩归档...${NC}"

    # 创建 tar.gz 归档
    if tar -czf "$archive_path" -T "$tmp_archive_list" 2>/dev/null; then
        local archive_size
        archive_size=$(stat --format="%s" "$archive_path" 2>/dev/null || echo "0")
        echo -e "  ${GREEN}✓ 归档完成:${NC} $(basename "$archive_path") ($(format_bytes "$archive_size"))"

        # 归档后删除原文件
        echo -e "${YELLOW}  是否删除原始日志文件以释放空间?${NC}"
        read -r -p "  删除原文件? [y/N]: " delete_confirm
        if [[ "$delete_confirm" == "y" || "$delete_confirm" == "Y" ]]; then
            local deleted_size=0
            while IFS= read -r f; do
                local fsize
                fsize=$(stat --format="%s" "$f" 2>/dev/null || echo "0")
                rm -f "$f" 2>/dev/null && deleted_size=$((deleted_size + fsize))
            done < "$tmp_archive_list"
            echo -e "  ${GREEN}✓ 已删除 $archive_count 个文件，释放 $(format_bytes "$deleted_size") 空间${NC}"
        fi
    else
        log_error "归档失败"
        rm -f "$archive_path" 2>/dev/null
    fi

    rm -f "$tmp_archive_list"

    # 显示现有归档文件
    echo
    echo -e "${CYAN}  当前归档文件:${NC}"
    ls -lh "$archive_dir"/*.tar.gz 2>/dev/null | head -5 | while IFS= read -r line; do
        echo -e "    ${GRAY}$(basename "$line")${NC}"
    done
}

# --- 模块主入口 ---
module_run() {
    print_title "日志分析引擎"
    echo -e "${BLUE}  运行时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    print_separator

    check_root

    # 子菜单
    while true; do
        echo
        echo -e "${CYAN}  请选择操作:${NC}"
        echo -e "  ${BOLD}1${NC}) 实时日志追踪"
        echo -e "  ${BOLD}2${NC}) 日志智能归类"
        echo -e "  ${BOLD}3${NC}) 日志归档压缩"
        echo -e "  ${BOLD}q${NC}) 返回"

        read -r -p "  请选择 [1-3/q]: " sub_choice

        case "$sub_choice" in
            1)
                real_time_track
                print_separator
                ;;
            2)
                classify_logs "${1:-$LOG_DIR}"
                print_separator
                ;;
            3)
                archive_logs "${1:-$LOG_DIR}" "$ARCHIVE_DIR" "$LOG_ARCHIVE_DAYS"
                print_separator
                ;;
            q|Q)
                break
                ;;
            *)
                echo -e "  ${YELLOW}无效选择${NC}"
                ;;
        esac
    done

    log_info "日志分析引擎使用完成"
}

# --- 模块帮助 ---
module_help() {
    cat <<EOF
模块: log_analyzer - 日志分析引擎

功能:
  实时追踪   - 利用 tail -f 结合 grep 实现日志流实时过滤与高亮显示
  智能归类   - 利用 awk 提取时间戳、服务名，按错误级别(ERROR/WARN/INFO)统计
  归档压缩   - 简易日志轮转，超设定天数打包为 .tar.gz 并移入归档目录

技术要点: 信号捕获(trap)、进程间通信(管道)、文件压缩解压

使用:
  ./module4_log_analyzer.sh     # 直接运行本模块
  ./module5_controller.sh       # 通过主控启动
EOF
}

# --- 直接运行时入口 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_run "$@"
fi
