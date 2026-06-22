#!/bin/bash
# ============================================================
# 模块二：用户活动追踪器 (User Activity Tracker)
# 功能: 实时登录监控、日志审计、权限检查
# ============================================================

source "$(cd "$(dirname "$0")" && pwd)/lib/common.sh"

MODULE_NAME="user_tracker"
MODULE_DESC="用户活动追踪器 - 登录监控、日志审计、权限检查"

register_module "$MODULE_NAME" "$MODULE_DESC"

# --- 实时登录用户监控 ---
track_current_users() {
    print_title "当前登录会话"

    # 使用 who 命令获取登录信息
    if ! command -v who &>/dev/null; then
        log_error "who 命令不可用"
        return 1
    fi

    local user_count
    user_count=$(who 2>/dev/null | wc -l)

    if [[ $user_count -eq 0 ]]; then
        echo -e "  ${YELLOW}当前无登录用户${NC}"
        return
    fi

    echo -e "  当前登录用户数: ${BOLD}${user_count}${NC}"
    print_separator "─"

    # 表头
    printf "${CYAN}  %-10s %-20s %-15s %s${NC}\n" "用户名" "登录时间" "IP地址" "终端"
    print_separator "─"

    while IFS= read -r line; do
        local user login_time ip_addr tty
        user=$(echo "$line" | awk '{print $1}')
        tty=$(echo "$line" | awk '{print $2}')
        login_time=$(echo "$line" | awk '{print $3, $4}')
        ip_addr=$(echo "$line" | awk '{print $5}' | sed 's/[()]//g')

        if [[ -z "$ip_addr" || "$ip_addr" == ":"* ]] || [[ "$ip_addr" == "0.0.0.0" ]]; then
            ip_addr="${GRAY}本地登录${NC}"
        else
            ip_addr="${YELLOW}$ip_addr${NC}"
        fi

        printf "  ${GREEN}%-10s${NC} %-20s %-20b %s\n" "$user" "$login_time" "$ip_addr" "$tty"
    done < <(who 2>/dev/null)

    # 显示每个用户的进程数
    print_separator "─"
    echo -e "${CYAN}  用户活动详情:${NC}"
    local users
    users=$(who 2>/dev/null | awk '{print $1}' | sort -u)
    for user in $users; do
        local proc_count
        proc_count=$(pgrep -u "$user" 2>/dev/null | wc -l)
        local last_cmd
        last_cmd=$(ps -u "$user" --sort=-start_time 2>/dev/null | head -2 | tail -1 | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}')
        printf "  ${GREEN}%-10s${NC} 进程数: ${WHITE}%-5d${NC} 最近命令: %s\n" "$user" "$proc_count "${last_cmd:0:40}""
    done
}

# --- 解析 /var/log/wtmp 登录历史 ---
audit_login_history() {
    print_title "登录历史审计"

    local log_file="/var/log/wtmp"
    if [[ ! -f "$log_file" ]]; then
        log_warn "找不到 $log_file，尝试使用 last 命令"
        if command -v last &>/dev/null; then
            echo -e "${CYAN}  最近10次登录记录:${NC}"
            last -10 2>/dev/null | head -12
        else
            log_error "last 命令不可用"
            return 1
        fi
        return
    fi

    # 使用 last 命令分析
    if command -v last &>/dev/null; then
        echo -e "${CYAN}  最近登录记录 (Top 15):${NC}"
        print_separator "─"
        printf "${CYAN}  %-10s %-15s %-20s %s${NC}\n" "用户名" "终端" "登录IP" "时间"
        print_separator "─"

        last -15 -F 2>/dev/null | head -15 | while IFS= read -r line; do
            if [[ -z "$line" ]] || [[ "$line" =~ ^(wtmp|btmp) ]]; then
                continue
            fi
            local user tty ip rest
            user=$(echo "$line" | awk '{print $1}')
            tty=$(echo "$line" | awk '{print $2}')
            ip=$(echo "$line" | awk '{print $3}')
            rest=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i}')

            # 过滤特殊行
            if [[ "$user" == "reboot" ]] || [[ "$user" == "shutdown" ]]; then
                printf "  ${PURPLE}%-10s${NC} %-15s %-50s\n" "$user" "$tty" "$rest"
            else
                printf "  ${GREEN}%-10s${NC} %-15s %-20s %s\n" "$user" "$tty" "$ip" "$rest"
            fi
        done

        # 统计信息
        echo
        local total_logins user_count
        total_logins=$(last 2>/dev/null | grep -v "^$" | grep -vc "wtmp" 2>/dev/null)
        local unique_users
        unique_users=$(last 2>/dev/null | awk '{print $1}' | grep -v "^$" | grep -v "wtmp" | sort -u | wc -l)
        echo -e "  总登录记录数: ${BOLD}${total_logins}${NC}  |  不同用户数: ${BOLD}${unique_users}${NC}"
    else
        log_error "last 命令不可用"
        return 1
    fi
}

# --- 登录失败审计 ---
audit_failed_logins() {
    print_title "登录失败审计 (暴力破解检测)"

    # 尝试多个可能的日志路径
    local auth_log=""
    local possible_logs=(
        "/var/log/auth.log"
        "/var/log/secure"
        "/var/log/auth.log.1"
        "/var/log/secure.1"
    )

    for log in "${possible_logs[@]}"; do
        if [[ -f "$log" ]] && [[ -r "$log" ]]; then
            auth_log="$log"
            break
        fi
    done

    if [[ -z "$auth_log" ]]; then
        log_warn "找不到认证日志文件"
        echo -e "  ${YELLOW}  提示: auth.log 通常位于 Ubuntu，secure 位于 CentOS${NC}"
        echo -e "  ${YELLOW}  请确认系统类型并检查日志路径${NC}"

        # 尝试 journalctl
        if command -v journalctl &>/dev/null; then
            echo
            echo -e "${CYAN}  尝试使用 journalctl 获取登录失败信息:${NC}"
            journalctl -u sshd -n 50 2>/dev/null | grep -i "failed\|invalid\|error" | tail -20
        fi
        return 1
    fi

    # 统计失败登录
    echo -e "  日志文件: ${WHITE}$auth_log${NC}"
    print_separator "─"

    # SSH 失败登录统计
    echo -e "${CYAN}  SSH 失败登录统计:${NC}"
    local fail_count
    fail_count=$(grep -c "Failed password" "$auth_log" 2>/dev/null)
    echo -e "    总失败次数: $(print_status "$fail_count" "$FAILED_LOGIN_THRESHOLD" "$((FAILED_LOGIN_THRESHOLD * 3))")"

    # 按用户统计失败登录
    echo
    echo -e "  ${CYAN}  按用户名统计失败登录 (Top 5):${NC}"
    grep "Failed password" "$auth_log" 2>/dev/null | \
        sed -n 's/.*Failed password for \([^ ]*\) .*/\1/p' | \
        sort | uniq -c | sort -rn | head -5 | while read count user; do
        printf "    ${YELLOW}%-20s${NC} 尝试 $(print_status "$count" "$FAILED_LOGIN_THRESHOLD" "$((FAILED_LOGIN_THRESHOLD * 3))") 次\n" "$user"
    done

    # 按 IP 统计失败登录
    echo
    echo -e "  ${CYAN}  按IP统计失败登录 (Top 5):${NC}"
    grep "Failed password" "$auth_log" 2>/dev/null | \
        sed -n 's/.*from \([0-9.]*\) .*/\1/p' | \
        sort | uniq -c | sort -rn | head -5 | while read count ip; do
        printf "    ${RED}%-20s${NC} 尝试 $(print_status "$count" "$FAILED_LOGIN_THRESHOLD" "$((FAILED_LOGIN_THRESHOLD * 3))") 次\n" "$ip"
    done

    # --- 检测暴力破解 ---
    echo
    echo -e "${CYAN}  暴力破解检测:${NC}"
    local brute_force=0
    while IFS= read -r line; do
        local count ip
        count=$(echo "$line" | awk '{print $1}')
        ip=$(echo "$line" | awk '{print $2}')
        if [[ $count -ge 10 ]]; then
            echo -e "    ${RED}⚠ 可疑IP: ${ip} (${count}次失败尝试)${NC}"
            brute_force=1
        fi
    done < <(grep "Failed password" "$auth_log" 2>/dev/null | \
        sed -n 's/.*from \([0-9.]*\) .*/\1/p' | \
        sort | uniq -c | sort -rn | head -10)

    if [[ $brute_force -eq 0 ]]; then
        echo -e "    ${GREEN}✓ 未检测到暴力破解行为${NC}"
    fi

    # 检查无效用户
    echo
    echo -e "  ${CYAN}  无效用户尝试:${NC}"
    local invalid_count
    invalid_count=$(grep -c "Invalid user" "$auth_log" 2>/dev/null)
    if [[ $invalid_count -gt 0 ]]; then
        echo -e "    ${RED}⚠ ${invalid_count} 次无效用户名尝试${NC}"
        grep "Invalid user" "$auth_log" 2>/dev/null | \
            sed -n 's/.*Invalid user \([^ ]*\) .*/\1/p' | \
            sort | uniq -c | sort -rn | head -5 | while read count user; do
            printf "    ${YELLOW}%-20s${NC} %d 次\n" "$user" "$count"
        done
    else
        echo -e "    ${GREEN}✓ 未发现无效用户尝试${NC}"
    fi
}

# --- 高权限用户审计 ---
audit_sudo_users() {
    print_title "权限审计 - 高权限用户操作轨迹"

    # 检查 /etc/sudoers
    echo -e "${CYAN}  特权用户 (sudo权限):${NC}"
    if [[ -f /etc/sudoers ]]; then
        local sudo_users
        sudo_users=$(grep -v "^#" /etc/sudoers 2>/dev/null | grep -v "^$" | grep -v "Defaults" | grep -v "Host_Alias" | grep -v "User_Alias" | grep -v "Cmnd_Alias")
        if [[ -n "$sudo_users" ]]; then
            echo "$sudo_users" | while IFS= read -r line; do
                echo -e "    ${YELLOW}$line${NC}"
            done
        fi
    else
        log_warn "找不到 /etc/sudoers"
    fi

    # 检查 sudo 组成员
    echo
    echo -e "${CYAN}  sudo/wheel 组成员:${NC}"
    for group in sudo wheel; do
        local members
        members=$(getent group "$group" 2>/dev/null | awk -F: '{print $4}')
        if [[ -n "$members" ]]; then
            echo -e "    ${GREEN}$group:${NC} $members"
        fi
    done

    # 查看最近 sudo 操作
    local auth_log=""
    [[ -f /var/log/auth.log ]] && auth_log="/var/log/auth.log"
    [[ -f /var/log/secure ]] && auth_log="/var/log/secure"

    if [[ -n "$auth_log" ]] && [[ -r "$auth_log" ]]; then
        echo
        echo -e "${CYAN}  最近 sudo 操作记录 (Top 10):${NC}"
        grep "sudo:" "$auth_log" 2>/dev/null | grep "COMMAND" | tail -10 | while IFS= read -r line; do
            local timestamp user cmd
            timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
            user=$(echo "$line" | sed -n 's/.*\([Uu]ser\) \([^ ]*\) .*/\2/p')
            cmd=$(echo "$line" | sed -n 's/.*COMMAND=\(.*\)/\1/p')
            if [[ -n "$cmd" ]]; then
                echo -e "    ${GRAY}[$timestamp]${NC} ${YELLOW}${user:-?}${NC} → $cmd"
            fi
        done

        # su 操作审计
        echo
        echo -e "${CYAN}  su 操作记录:${NC}"
        local su_count
        su_count=$(grep -c "su:" "$auth_log" 2>/dev/null)
        if [[ $su_count -gt 0 ]]; then
            grep "su:" "$auth_log" 2>/dev/null | tail -5 | while IFS= read -r line; do
                echo -e "    ${GRAY}$line${NC}"
            done
        else
            echo -e "    ${GREEN}✓ 未发现 su 操作记录${NC}"
        fi
    fi
}

# --- 模块主入口 ---
module_run() {
    print_title "用户活动追踪器"
    echo -e "${BLUE}  运行时间: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    print_separator

    check_root
    print_separator

    track_current_users
    print_separator

    audit_login_history
    print_separator

    audit_failed_logins
    print_separator

    audit_sudo_users

    log_info "用户活动追踪完成"
    echo
    echo -e "${GREEN}  ✔ 追踪完成！${NC}"
    read -r -p "按回车键继续..."
}

# --- 模块帮助 ---
module_help() {
    cat <<EOF
模块: user_tracker - 用户活动追踪器

功能:
  实时监控   - 解析 who 命令和 /var/run/utmp，列出当前登录会话详情
  日志审计   - 解析 /var/log/wtmp 和 auth.log/secure，统计登录失败，识别暴力破解
  权限检查   - 解析 /etc/sudoers 及 auth.log，审计高权限用户操作轨迹

技术要点: 日志轮转机制理解、正则表达式(grep/sed)精准匹配

使用:
  ./module2_user_tracker.sh     # 直接运行本模块
  ./module5_controller.sh       # 通过主控启动
EOF
}

# --- 直接运行时入口 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    module_run
fi
