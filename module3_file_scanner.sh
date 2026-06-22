#!/bin/bash
# ============================================================
# 模块三：文件系统扫描仪 (File System Scanner)
# 功能: 空间预警、大文件清理、安全扫描
# ============================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

MODULE_NAME="file_scanner"
MODULE_DESC="文件系统扫描仪 - 磁盘空间、大文件清理、安全扫描"

register_module "$MODULE_NAME" "$MODULE_DESC"

# --- 磁盘空间预警 ---
disk_space_warning() {
    print_title "磁盘空间预警"

    if ! command -v df &>/dev/null; then
        log_error "df 命令不可用"
        return 1
    fi

    echo -e "${CYAN}  挂载点使用情况:${NC}"
    print_separator "─"
    printf "${CYAN}  %-20s %-9s %-9s %-9s %-5s %s${NC}\n" "文件系统" "总大小" "已用" "可用" "使用%" "挂载点"
    print_separator "─"

    local alarm_count=0
    while IFS= read -r line; do
        local fs usage mount
        fs=$(echo "$line" | awk '{print $1}')
        local size used avail pct
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        avail=$(echo "$line" | awk '{print $4}')
        pct=$(echo "$line" | awk '{print $5}' | sed 's/%//')
        mount=$(echo "$line" | awk '{print $6}')

        # 跳过来自 systemd 和临时文件系统
        [[ "$fs" == "tmpfs" || "$fs" == "devtmpfs" || "$fs" == "overlay" ]] && continue
        [[ "$mount" == "/snap/"* ]] && continue
        [[ "$mount" == "/boot/"* && "$mount" != "/boot" ]] && continue

        local pct_colored
        if [[ $pct -ge $DISK_ALARM_THRESHOLD ]]; then
            pct_colored=$(print_status "$pct%" 70 "$DISK_ALARM_THRESHOLD")
            alarm_count=$((alarm_count + 1))
        elif [[ $pct -ge 70 ]]; then
            pct_colored=$(print_status "$pct%" 70 "$DISK_ALARM_THRESHOLD")
        else
            pct_colored="${GREEN}${pct}%${NC}"
        fi

        printf "  %-20s %-9s %-9s %-9s %b %s\n" "$fs" "$size" "$used" "$avail" "$pct_colored" "$mount"

        # 进度条
        local bar_len=20
        local filled
        filled=$(( pct * bar_len / 100 ))
        printf "  %20s " ""
        for ((i=0; i<bar_len; i++)); do
            if [[ $i -lt $filled ]]; then
                if [[ $i -lt $(( bar_len * 70 / 100 )) ]]; then
                    echo -ne "${GREEN}█${NC}"
                elif [[ $i -lt $(( bar_len * 90 / 100 )) ]]; then
                    echo -ne "${YELLOW}█${NC}"
                else
                    echo -ne "${RED}█${NC}"
                fi
            else
                echo -ne "${GRAY}░${NC}"
            fi
        done
        echo " ${pct}%"

    done < <(df -h 2>/dev/null | tail -n +2)

    print_separator "─"

    # 告警汇总
    if [[ $alarm_count -gt 0 ]]; then
        echo -e "  ${RED}⚠ ${alarm_count} 个分区使用率超过 ${DISK_ALARM_THRESHOLD}%！${NC}"
        df -h 2>/dev/null | tail -n +2 | while IFS= read -r line; do
            local pct
            pct=$(echo "$line" | awk '{print $5}' | sed 's/%//')
            local mount
            mount=$(echo "$line" | awk '{print $6}')
            if [[ $pct -ge $DISK_ALARM_THRESHOLD ]]; then
                echo -e "    ${RED}⚠ ${mount} (${pct}%) - 需要立即处理${NC}"
            fi
        done
    else
        echo -e "  ${GREEN}✓ 所有分区使用率正常${NC}"
    fi

    # 目录大小排行
    echo
    echo -e "${CYAN}  当前目录下大小排行 (Top 5):${NC}"
    du -sh ./* 2>/dev/null | sort -rh | head -5 | while IFS= read -r line; do
        echo "    $line"
    done
}

# --- 大文件查找 ---
find_large_files() {
    print_title "大文件查找"

    local search_dir="${1:-/var}"
    local size_filter="${2:-$LARGE_FILE_SIZE}"
    local mtime_filter="${3:-$OLD_FILE_MTIME}"

    # 检查是否为目录
    if [[ ! -d "$search_dir" ]]; then
        log_error "目录不存在: $search_dir"
        return 1
    fi

    if ! command -v find &>/dev/null; then
        log_error "find 命令不可用"
        return 1
    fi

    echo -e "  搜索目录: ${CYAN}$search_dir${NC}"
    echo -e "  文件大小: ${YELLOW}$size_filter${NC}"
    echo -e "  修改时间: ${YELLOW}${mtime_filter}天前${NC}"

    print_separator "─"

    local tmpfile
    tmpfile=$(mktemp /tmp/.toolkit_large_files.XXXXXX)

    echo -e "${CYAN}  正在扫描大文件 (> $size_filter)...${NC}"

    local find_cmd="find \"$search_dir\" -type f -size \"$size_filter\""
    [[ -n "$mtime_filter" ]] && find_cmd+=" -mtime \"$mtime_filter\""
    find_cmd+=" 2>/dev/null"

    eval "$find_cmd" | head -50 > "$tmpfile"
    local file_count
    file_count=$(wc -l < "$tmpfile")

    if [[ $file_count -eq 0 ]]; then
        echo -e "  ${GREEN}✓ 未找到符合条件的文件${NC}"
        rm -f "$tmpfile"
        return
    fi

    echo -e "  找到 ${BOLD}${file_count}${NC} 个文件（仅显示前50个）"
    echo

    # 文件详情
    local total_size=0
    local idx=0
    while IFS= read -r file; do
        idx=$((idx + 1))
        local fsize fdate fper
        fsize=$(stat --format="%s" "$file" 2>/dev/null || echo "0")
        fdate=$(stat --format="%y" "$file" 2>/dev/null | cut -d'.' -f1)
        fper=$(stat --format="%a" "$file" 2>/dev/null)

        printf "  ${BOLD}%3d.${NC} %-50s\n" "$idx" "${file:0:50}"
        printf "      大小: ${YELLOW}%s${NC}  修改: ${GRAY}%s${NC}  权限: ${PURPLE}%s${NC}\n" \
            "$(format_bytes "$fsize")" "$fdate" "$fper"

        total_size=$((total_size + fsize))
    done < "$tmpfile"

    echo
    echo -e "  文件总数: ${BOLD}${file_count}${NC}  总大小: ${YELLOW}$(format_bytes "$total_size")${NC}"

    # 交互式清理
    echo
    echo -e "${YELLOW}  ┌─────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}  │  是否要交互式清理这些文件?                     │${NC}"
    echo -e "${YELLOW}  └─────────────────────────────────────────────┘${NC}"
    read -r -p "  进入清理模式? [y/N]: " cleanup_choice

    if [[ "$cleanup_choice" == "y" || "$cleanup_choice" == "Y" ]]; then
        interactive_cleanup "$tmpfile"
    fi

    rm -f "$tmpfile"
}

# --- 交互式清理 ---
interactive_cleanup() {
    local filelist="$1"
    local idx=0
    local deleted=0

    echo
    echo -e "${RED}  ⚠ 进入交互式删除模式，请谨慎操作！${NC}"
    echo -e "${GRAY}  按 y 删除，按 n 跳过，按 q 退出${NC}"
    print_separator "─"

    while IFS= read -r file; do
        idx=$((idx + 1))
        local fsize
        fsize=$(stat --format="%s" "$file" 2>/dev/null || echo "0")

        echo
        echo -e "  [${BOLD}${idx}${NC}] ${YELLOW}${file}${NC}"
        echo -e "      大小: $(format_bytes "$fsize")"

        read -r -p "  删除此文件? [y/n/q]: " choice
        case "$choice" in
            y|Y)
                if rm -f "$file" 2>/dev/null; then
                    echo -e "    ${GREEN}✓ 已删除${NC}"
                    deleted=$((deleted + 1))
                else
                    echo -e "    ${RED}✗ 删除失败（权限不足）${NC}"
                fi
                ;;
            n|N)
                echo -e "    ${GRAY}已跳过${NC}"
                ;;
            q|Q)
                echo -e "    ${GRAY}退出清理${NC}"
                break
                ;;
            *)
                echo -e "  无效选择，跳过"
                ;;
        esac
    done < "$filelist"

    echo
    echo -e "  共删除 ${RED}${deleted}${NC} 个文件"
}

# --- 权限安全扫描 ---
security_scan() {
    print_title "安全扫描 - 文件权限检查"

    # 需要检查的目录
    local scan_dirs=("${SCAN_DIRS[@]}")

    # --- World Writable 文件检查 ---
    echo -e "${CYAN}  1. 全局可写(World Writable)文件检查${NC}"
    print_separator "─"

    local ww_found=0
    for dir in "${scan_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_debug "目录不存在: $dir，跳过"
            continue
        fi

        local ww_count
        ww_count=$(find "$dir" -type f -perm -o=w 2>/dev/null | wc -l)
        if [[ $ww_count -gt 0 ]]; then
            echo -e "  ${RED}⚠ ${dir}: 发现 ${ww_count} 个全局可写文件${NC}"
            find "$dir" -type f -perm -o=w 2>/dev/null | head -10 | while read f; do
                local perm owner
                perm=$(stat --format="%A" "$f" 2>/dev/null)
                owner=$(stat --format="%U:%G" "$f" 2>/dev/null)
                printf "    ${YELLOW}%-50s${NC} %s %s\n" "${f:0:50}" "$perm" "$owner"
            done
            ww_found=$((ww_found + ww_count))
        fi
    done

    if [[ $ww_found -eq 0 ]]; then
        echo -e "  ${GREEN}✓ 未发现全局可写文件${NC}"
    fi

    # --- SUID/SGID 检查 ---
    echo
    echo -e "${CYAN}  2. SUID/SGID 异常位检查${NC}"
    print_separator "─"

    local sg_found=0
    for dir in "${scan_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        local sg_count
        sg_count=$(find "$dir" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
        if [[ $sg_count -gt 0 ]]; then
            echo -e "  ${dir}: ${YELLOW}${sg_count}${NC} 个特殊权限文件"
            # 列出详细
            find "$dir" -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while read f; do
                local perm owner
                perm=$(stat --format="%A" "$f" 2>/dev/null)
                owner=$(stat --format="%U:%G" "$f" 2>/dev/null)
                local suid_type=""
                [[ -u "$f" ]] && suid_type="${RED}SUID${NC}"
                [[ -g "$f" ]] && suid_type="${YELLOW}SGID${NC}"
                printf "    ${BOLD}%-50s${NC} %s %-15s %b\n" "${f:0:50}" "$perm" "$owner" "$suid_type"
            done
            sg_found=$((sg_found + sg_count))
        fi
    done

    # 列出一些众所周知必要的SUID文件进行检查
    echo
    echo -e "  ${CYAN}  常见需关注SUID文件:${NC}"
    local known_suid=("/usr/bin/sudo" "/usr/bin/passwd" "/usr/bin/ping" "/bin/ping"
                     "/usr/bin/chsh" "/usr/bin/gpasswd" "/usr/bin/newgrp"
                     "/usr/sbin/unix_chkpwd")
    for f in "${known_suid[@]}"; do
        if [[ -f "$f" ]]; then
            local perm
            perm=$(stat --format="%A" "$f" 2>/dev/null)
            if [[ "$perm" == *"s"* ]]; then
                echo -e "    ${GREEN}✓${NC} $f (正常SUID: $perm)"
            fi
        fi
    done

    # --- 隐蔽文件检查 ---
    echo
    echo -e "${CYAN}  3. 可疑隐藏文件检查${NC}"
    print_separator "─"

    local suspicious_total=0
    for dir in /tmp /var/tmp /dev/shm; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        local sus_count
        sus_count=$(find "$dir" -maxdepth 2 -name ".*" -type f 2>/dev/null | wc -l)
        if [[ $sus_count -gt 0 ]]; then
            echo -e "  ${dir}: ${YELLOW}${sus_count}${NC} 个隐藏文件"
            find "$dir" -maxdepth 2 -name ".*" -type f -exec ls -la {} \; 2>/dev/null | head -5
            suspicious_total=$((suspicious_total + sus_count))
        fi
    done

    if [[ $suspicious_total -eq 0 ]]; then
        echo -e "  ${GREEN}✓ 未发现可疑隐藏文件${NC}"
    fi

    # --- 权限摘要 ---
    echo
    print_separator "═"
    echo -e "${CYAN}  安全扫描摘要:${NC}"
    echo -e "  World Writable 文件: $(print_status "$ww_found" "5" "20")"
    echo -e "  SUID/SGID 文件:    $(print_status "$sg_found" "50" "100")"
    echo -e "  可疑隐藏文件:       $(print_status "$suspicious_total" "5" "20")"

    if [[ $ww_found -gt 10 ]]; then
        echo -e "  ${RED}  ⚠ 系统存在过多全局可写文件，可能存在安全隐患${NC}"
    fi
}

# --- 模块主入口 ---
module_run() {
    print_title "文件系统扫描仪"
    echo -e "${BLUE}  扫描时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    print_separator

    # 参数解析
    local search_dir="${1:-/var}"
    local size_filter="${2:-$LARGE_FILE_SIZE}"
    local mtime_filter="${3:-$OLD_FILE_MTIME}"

    # 处理传入参数中的特殊格式（如从主控传入的参数）
    if [[ -n "$ARGV" ]]; then
        local args=($ARGV)
        [[ -n "${args[0]}" ]] && search_dir="${args[0]}"
        [[ -n "${args[1]}" ]] && size_filter="${args[1]}"
        [[ -n "${args[2]}" ]] && mtime_filter="${args[2]}"
    fi

    disk_space_warning
    print_separator

    find_large_files "$search_dir" "$size_filter" "$mtime_filter"
    print_separator

    security_scan

    log_info "文件系统扫描完成"
    echo
    echo -e "${GREEN}  ✔ 扫描完成！${NC}"
    read -r -p "按回车键继续..."
}

# --- 模块帮助 ---
module_help() {
    cat <<EOF
模块: file_scanner - 文件系统扫描仪

功能:
  空间预警   - 递归统计目录大小，对比磁盘配额，超阈值告警
  大文件清理 - 按大小(-size +100M)、时间(-mtime +30)筛选，交互式删除
  安全扫描   - 检查关键目录 World Writable 权限和 SUID/SGID 异常位

技术要点: find命令高级用法、文件权限位八进制转换与逻辑判断

使用:
  ./module3_file_scanner.sh                     # 默认扫描
  ./module3_file_scanner.sh /home +50M +7       # 自定义参数
  ./module5_controller.sh                       # 通过主控启动
EOF
}

# --- 直接运行时入口 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_run "$@"
fi
