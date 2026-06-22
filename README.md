# Linux 系统运维工具箱

**操作系统课程设计项目** | Linux System Administration Toolkit

---

## 📋 项目概述

本项目实现了一个模块化的 Linux 系统运维工具箱，包含五个核心功能模块，采用统一的接口规范，可独立运行或通过主控中心集成调用。

## 🏗️ 项目结构

```
LinuxSysToolkit/
├── module1_sysmonitor.sh     # 模块一：系统性能监控仪
├── module2_user_tracker.sh   # 模块二：用户活动追踪器
├── module3_file_scanner.sh   # 模块三：文件系统扫描仪
├── module4_log_analyzer.sh   # 模块四：日志分析引擎
├── module5_controller.sh     # 模块五：主控与调度中心
├── lib/
│   ├── common.sh             # 公共函数库（颜色、日志、工具函数）
│   └── config.sh             # 全局配置文件（阈值、路径等）
├── report/                   # 报告输出目录
├── archive/                  # 日志归档目录
└── README.md                 # 本文件
```

## 🔧 各模块功能

### 模块一：系统性能监控仪 (`module1_sysmonitor.sh`)
- **CPU 监控**：实时获取整体及各核心使用率，计算平均负载，绘制 ASCII Art 负载趋势图
- **内存分析**：区分物理内存与 Swap 空间，计算使用百分比，超阈值颜色告警
- **进程排行**：动态列出资源消耗 Top 5 进程（PID、名称、CPU/内存占比）

### 模块二：用户活动追踪器 (`module2_user_tracker.sh`)
- **实时监控**：解析当前登录会话详情（用户、时间、IP、终端）
- **日志审计**：解析登录历史，统计登录失败次数，识别暴力破解尝试
- **权限检查**：审计 sudo 权限用户和高权限用户操作轨迹

### 模块三：文件系统扫描仪 (`module3_file_scanner.sh`)
- **空间预警**：递归统计目录大小，对比磁盘配额，标记超阈值挂载点
- **大文件清理**：按大小、时间筛选文件，提供交互式删除确认功能
- **安全扫描**：检查关键目录 World Writable 权限和 SUID/SGID 异常位

### 模块四：日志分析引擎 (`module4_log_analyzer.sh`)
- **实时追踪**：利用 `tail -f` 结合 `grep` 实现日志流实时过滤与高亮显示
- **智能归类**：按服务名、错误级别（ERROR/WARN/INFO）进行统计
- **归档压缩**：实现简易日志轮转，超设定天数打包为 `.tar.gz`

### 模块五：主控与调度中心 (`module5_controller.sh`)
- **交互界面**：支持 dialog/whiptail 图形化菜单和终端文本菜单
- **调度策略**：支持交互式执行、定时任务（crontab）和守护进程模式
- **报告生成**：整合各模块输出生成 HTML 格式系统健康报告，含健康评分

## 🚀 快速开始

### 1. 赋予执行权限

```bash
chmod +x module*.sh lib/*.sh
```

### 2. 启动主控菜单

```bash
./module5_controller.sh
```

### 3. 直接运行单个模块

```bash
./module1_sysmonitor.sh    # 系统性能监控
./module2_user_tracker.sh  # 用户活动追踪
./module3_file_scanner.sh  # 文件系统扫描
./module4_log_analyzer.sh  # 日志分析
```

### 4. 命令行选项（主控模块）

```bash
./module5_controller.sh --help       # 显示帮助
./module5_controller.sh --quiet     # 安静模式（执行所有模块）
./module5_controller.sh --module 3  # 只运行模块三
./module5_controller.sh --daemon    # 守护进程模式
./module5_controller.sh --report    # 生成 HTML 健康报告
./module5_controller.sh --cron      # 配置定时任务
```

## ⚙️ 配置说明

配置文件 `lib/config.sh` 可调整以下参数：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `CPU_ALARM_THRESHOLD` | CPU 告警阈值 | 80% |
| `MEM_ALARM_THRESHOLD` | 内存告警阈值 | 80% |
| `DISK_ALARM_THRESHOLD` | 磁盘告警阈值 | 90% |
| `FAILED_LOGIN_THRESHOLD` | 登录失败告警阈值 | 5次 |
| `LARGE_FILE_SIZE` | 大文件判定阈值 | +100M |
| `LOG_ARCHIVE_DAYS` | 日志归档天数 | 7天 |
| `DAEMON_INTERVAL` | 守护进程间隔 | 60秒 |

## 📊 输出示例

- **终端**：彩色文字输出，含进度条和图表
- **日志**：记录到 `toolkit.log`
- **报告**：HTML 格式系统健康报告（`report/` 目录）
- **归档**：压缩日志包（`archive/` 目录）

## 🔒 权限说明

- 部分功能（如用户审计、日志读取）需要 **root 权限**
- 建议使用 `sudo` 运行以获得完整功能
- 守护进程模式下，确保日志路径可写

## 💡 技术要点

- `/proc` 文件系统解析
- `awk` 数值计算与文本处理
- `find` 命令高级用法
- 正则表达式精准匹配（grep/sed）
- 信号捕获（trap 命令）
- Shell 函数库封装
- HTML 报告拼接生成

## 📝 环境要求

- **操作系统**：Linux (Ubuntu 22.04+ / CentOS Stream 8+)
- **Shell**：Bash 4.0+
- **可选工具**：dialog 或 whiptail（提供图形化菜单）

---

*课程设计项目 | 操作系统 (第5版) | 信息与管理科学学院（软件学院）*
