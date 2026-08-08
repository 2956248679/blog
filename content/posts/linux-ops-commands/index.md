---
title: "Linux 运维常用命令速查手册"
date: 2026-08-06T20:00:00+08:00
draft: false
tags: ["Linux", "运维"]
summary: "整理 Linux 服务器运维最常用的命令，涵盖系统监控、进程管理、日志排查、磁盘网络等场景，适合运维新人收藏备用。"
---

## 系统信息

```bash
# 系统版本
cat /etc/os-release
uname -a

# 运行时间 + 负载
uptime
# 输出: 14:30:00 up 30 days, 2 users, load average: 0.05, 0.03, 0.01

# 内存使用
free -h

# 磁盘使用
df -h
du -sh /var/log/*
```

## 进程管理

```bash
# 实时进程监控
htop          # 彩色界面，比 top 好用
top -u root   # 只看 root 的进程

# 查找进程
ps aux | grep nginx
pgrep -f nginx

# 杀进程
kill -9 PID
pkill -f "process_name"

# 查看进程树
pstree -p
```

## 端口与网络

```bash
# 监听端口
ss -tlnp       # TCP 监听
ss -ulnp       # UDP 监听

# 网络连接状态统计
ss -s

# 查看外网 IP
curl -s ifconfig.me

# DNS 解析测试
dig www.lihuanyu.icu
nslookup www.lihuanyu.icu
```

## 日志排查

```bash
# 实时查看日志
tail -f /var/log/nginx/access.log

# 搜索关键词
grep "ERROR" /var/log/syslog

# 按时间范围查日志
journalctl --since "2026-08-08" --until "2026-08-08 12:00"

# Nginx 访问量 Top10 IP
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
```

## 磁盘与文件

```bash
# 查找大文件
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null

# 文件数量
ls -l | wc -l

# 快速清空日志文件
> /var/log/app.log     # 不清除 inode
truncate -s 0 /var/log/app.log

# 文件搜索
find /var/www -name "*.log"
grep -r "TODO" /opt/project/
```

## 用户与权限

```bash
# 创建用户
useradd -m -s /bin/bash username

# 添加 sudo 权限
usermod -aG sudo username

# 查看登录记录
last -10

# 当前登录用户
who
```

## 定时任务

```bash
# 编辑 crontab
crontab -e

# 格式: 分 时 日 月 周
# 每天 2 点备份
0 2 * * * /opt/scripts/backup.sh

# 列出当前任务
crontab -l
```

## Shell 脚本模板

```bash
#!/bin/bash
set -euo pipefail  # 遇错退出 + 未定义变量报错

LOG_FILE="/var/log/check.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

check_disk() {
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -gt 80 ]; then
        log "WARN: 磁盘使用率 ${usage}%"
    else
        log "OK: 磁盘使用率 ${usage}%"
    fi
}

main() {
    log "开始巡检..."
    check_disk
    log "巡检完成"
}

main "$@"
```

## 总结

这些命令是运维日常最高频使用的。建议：**不要死记硬背，配好 alias 和脚本**。运维的核心能力不是记命令，而是**快速定位问题 + 写自动化脚本**。
