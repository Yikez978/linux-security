#!/bin/bash

#########################
# 用语的统一
# ACCEPT : 允许
# DROP :   丢弃
# REJECT : 拒绝
#########################

# 速查表
#
# - A，-- append 连锁指定一个以上的新规则追加
# - D，-- delete 指定连锁从一个以上的规则删除
# - P，-- policy 指定连锁的政策的指定的目标设定
# - N，-- new - chain 创造新用户定义链
# - X，-- delete - chain 指定删除用户定义链
# - F 初始化表
#
# - p，-- protocol   协议（tcp，udp，icmp all）
# - s，-- source IP  地址 [ / mask ]源地址（IP 地址或主机名）
# - d，-- destination IP 地址 [ / mask ] 目标地址（IP 地址或主机名）
# - i，-- in - interface  包进入网卡指定
# - o，-- out - interface  包出去网卡指定
# - j，-- JUMP target  规则目标
# - t，-- table  表
# - m state -- state  包的状态的条件指定
# state，NEW，ESTABLISHED，RELATED，INVALID 可以指定的状态
#！条件反转（～以外的）
#########################

# PATH
PATH=/sbin:/usr/sbin:/bin:/usr/bin

###########################################################
# IP 定义
###########################################################

# 内部网络，在外网中不需要设置
# LOCAL_NET="xxx.xxx.xxx.xxx/xx"

# 内部限制的网络范围
# LIMITED_LOCAL_NET="xxx.xxx.xxx.xxx/xx"

# Zabbix IP，这里填 server 的 IP 地址或主机名
# ZABBIX_IP="xxx.xxx.xxx.xxx"

# 所有的 IP
# ANY="0.0.0.0/0"

# 允许主机，这里可以设置为自己的局域网所在的外网 IP
# ALLOW_HOSTS=(
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
# )

# 禁止主机
# DENY_HOSTS=(
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
# )

###########################################################
# 端口定义
###########################################################
OTHER_SERVICE_PORT=${OTHER_SERVICE_PORT}
#SSH=22
#HTTP=80
#HTTPS=443
#POSTGRESQL=5432
#FTP=20,21
#DNS=53
#SMTP=25,465,587
#POP3=110,995
#IMAP=143,993
#IDENT=113
#NTP=123
#MYSQL=3306
#NET_BIOS=135,137,138,139,445
#DHCP=67,68

###########################################################
# 函数
###########################################################

# iptables 初始化，删除所有规则
initialize()
{
    iptables -F # 初始化
    iptables -X # 删除链
    iptables -Z # 清除包、字节计数器
    iptables -P INPUT   ACCEPT
    iptables -P OUTPUT  ACCEPT
    iptables -P FORWARD ACCEPT
}

# 处理完成后的动作
finailize()
{
    /etc/init.d/iptables save && # 保存設置
    /etc/init.d/iptables restart && # 重启
        return 0
    return 1
}

# 开发模式
if [ "$1" == "dev" ]
then
    iptables() { echo "iptables $@"; }
    finailize() { echo "finailize"; }
fi

###########################################################
# iptables 初始化
###########################################################
initialize

###########################################################
# 策略
###########################################################
iptables -P INPUT   DROP # 默认丢弃所有，只允许必要端口通过
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD DROP

###########################################################
# 允许的主机策略
###########################################################

# 本地主机
# 本地环回
iptables -A INPUT -i lo -j ACCEPT # SELF -> SELF

# 本地网络
# 允许来自 $LOCAL_NET 接入
if [ "$LOCAL_NET" ]
then
    iptables -A INPUT -p tcp -s $LOCAL_NET -j ACCEPT # LOCAL_NET -> SELF
fi

# 允许主机
# 允许 $ALLOW_HOSTS 中主机通信
if [ "${ALLOW_HOSTS}" ]
then
    for allow_host in ${ALLOW_HOSTS[@]}
    do
        iptables -A INPUT -p tcp -s $allow_host -j ACCEPT # allow_host -> SELF
    done
fi

###########################################################
# $DENY_HOSTS 丢弃策略
###########################################################
if [ "${DENY_HOSTS}" ]
then
    for deny_host in ${DENY_HOSTS[@]}
    do
        iptables -A INPUT -s $deny_host -m limit --limit 1/s -j LOG --log-prefix "deny_host: "
        iptables -A INPUT -s $deny_host -j DROP
    done
fi

###########################################################
# 已建立session的包，接受
###########################################################
iptables -A INPUT  -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT

###########################################################
# 攻击应对: 扫描
###########################################################
iptables -N STEALTH_SCAN # 新建 "STEALTH_SCAN" 链
iptables -A STEALTH_SCAN -j LOG --log-prefix "stealth_scan_attack: "
iptables -A STEALTH_SCAN -j DROP

# 类似扫描的包，跳转到 "STEALTH_SCAN" 链
iptables -A INPUT -p tcp --tcp-flags SYN,ACK SYN,ACK -m state --state NEW -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j STEALTH_SCAN

iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN         -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST         -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j STEALTH_SCAN

iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN     -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH     -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG     -j STEALTH_SCAN

###########################################################
# 攻击应对: 包端口扫描，DOS攻击
# namap -v -sF 等对策
###########################################################
iptables -A INPUT -f -j LOG --log-prefix 'fragment_packet:'
iptables -A INPUT -f -j DROP

###########################################################
# 攻击应对: "Ping of Death"
###########################################################
# 每秒回应，超过10次以上就丢弃
iptables -N PING_OF_DEATH # 新建 "PING_OF_DEATH" 链
iptables -A PING_OF_DEATH -p icmp --icmp-type echo-request \
         -m hashlimit \
         --hashlimit 1/s \
         --hashlimit-burst 10 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_PING_OF_DEATH \
         -j RETURN

# "Ping of Death" 攻击对应
iptables -A PING_OF_DEATH -j LOG --log-prefix "ping_of_death_attack: "
iptables -A PING_OF_DEATH -j DROP

# ICMP 跳转至 "PING_OF_DEATH" 链
iptables -A INPUT -p icmp --icmp-type echo-request -j PING_OF_DEATH

###########################################################
# 攻击应对: SYN Flood Attack
# 这个策略之外再加上 SYN_COOKIE 有效。
###########################################################
iptables -N SYN_FLOOD # 新建 "SYN_FLOOD" 链
iptables -A SYN_FLOOD -p tcp --syn \
         -m hashlimit \
         --hashlimit 200/s \
         --hashlimit-burst 3 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_SYN_FLOOD \
         -j RETURN

# 说明
# -m hashlimit                       限速模块
# --hashlimit 200/s                  每秒连接上限 200
# --hashlimit-burst 3                连续超过 3 次
# --hashlimit-htable-expire 300000   记录有效期（单位：ms
# --hashlimit-mode srcip             对源地址进行 hashlimit
# --hashlimit-name t_SYN_FLOOD       /proc/net/ipt_hashlimit 存储hash表
# -j RETURN                          超出制限，则返回

# 对超出的包丢弃
iptables -A SYN_FLOOD -j LOG --log-prefix "syn_flood_attack: "
iptables -A SYN_FLOOD -j DROP

# SYN 包跳至 SYN_FLOOD 链
iptables -A INPUT -p tcp --syn -j SYN_FLOOD

###########################################################
# 攻击应对: HTTP DoS/DDoS Attack
###########################################################
iptables -N HTTP_DOS # 新建 "HTTP_DOS" 链
iptables -A HTTP_DOS -p tcp -m multiport --dports $HTTP \
         -m hashlimit \
         --hashlimit 1/s \
         --hashlimit-burst 100 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_HTTP_DOS \
         -j RETURN

# 说明
# -m hashlimit                       限速模块
# --hashlimit 1/s                    每秒连接上限 1
# --hashlimit-burst 100              连续超过 100 次
# --hashlimit-htable-expire 300000   记录有效期（单位：ms
# --hashlimit-mode srcip             对源地址进行 hashlimit
# --hashlimit-name t_HTTP_DOS        /proc/net/ipt_hashlimit 存储hash表
# -j RETURN                          超出制限，则返回

# 对超出的包丢弃
iptables -A HTTP_DOS -j LOG --log-prefix "http_dos_attack: "
iptables -A HTTP_DOS -j DROP

# HTTP 的包，跳转至 HTTP_DOS 链
iptables -A INPUT -p tcp -m multiport --dports $HTTP -j HTTP_DOS

###########################################################
# 攻击应对: IDENT port probe
# 可能会会使某些服务反应下降，例如『邮件服务』
###########################################################
iptables -A INPUT -p tcp -m multiport --dports $IDENT -j REJECT --reject-with tcp-reset

###########################################################
# 攻击应对: SSH Brute Force
# 暴力 SSH 密码攻击
# 1 分钟内 5 次 SSH 则视为 "ssh_attack"
# SSH 拒绝连接，而不是让用户重新连接
# 如果 SSH 使用密码登陆方式，取消注释可开启
###########################################################
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --set
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ssh_brute_force: "
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset

###########################################################
# 攻击应对: FTP Brute Force
# 暴力 FTP 密码攻击
# 1 分钟内 5 次 SSH 则视为 "ftp_attack"
# FTP 拒绝连接，而不是让用户重新连接
# 如果 FTP 使用密码登陆方式，取消注释可开启
###########################################################
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --set
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ftp_brute_force: "
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset

###########################################################
# 所有主机（广播、多播地址）寻址分组丢弃
###########################################################
iptables -A INPUT -d 192.168.1.255   -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 192.168.1.255   -j DROP
iptables -A INPUT -d 255.255.255.255 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 255.255.255.255 -j DROP
iptables -A INPUT -d 224.0.0.1       -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 224.0.0.1       -j DROP

###########################################################
# 来自所有主机的 INPUT（ANY）
###########################################################

# ICMP: 响应 ping
iptables -A INPUT -p icmp -j ACCEPT # ANY -> SELF

# HTTP, HTTPS
iptables -A INPUT -p tcp -m multiport --dports $SERVICE_PORT -j ACCEPT # ANY -> SELF

# SSH: 如果要限制 TRUST_HOSTS 进入，注释掉以下：
#iptables -A INPUT -p tcp -m multiport --dports $SSH -j ACCEPT # ANY -> SEL

# FTP
# iptables -A INPUT -p tcp -m multiport --dports $FTP -j ACCEPT # ANY -> SELF

# DNS
# iptables -A INPUT -p tcp -m multiport --sports $DNS -j ACCEPT # ANY -> SELF
# iptables -A INPUT -p udp -m multiport --sports $DNS -j ACCEPT # ANY -> SELF

# SMTP
# iptables -A INPUT -p tcp -m multiport --sports $SMTP -j ACCEPT # ANY -> SELF

# POP3
# iptables -A INPUT -p tcp -m multiport --sports $POP3 -j ACCEPT # ANY -> SELF

# IMAP
# iptables -A INPUT -p tcp -m multiport --sports $IMAP -j ACCEPT # ANY -> SELF

###########################################################
# 允许的本地网络范围
###########################################################

if [ "$LIMITED_LOCAL_NET" ]
then
    # SSH
    iptables -A INPUT -p tcp -s $LIMITED_LOCAL_NET -m multiport --dports $SSH -j ACCEPT # LIMITED_LOCAL_NET -> SELF

    # FTP
    iptables -A INPUT -p tcp -s $LIMITED_LOCAL_NET -m multiport --dports $FTP -j ACCEPT # LIMITED_LOCAL_NET -> SELF

    # MySQL
    iptables -A INPUT -p tcp -s $LIMITED_LOCAL_NET -m multiport --dports $MYSQL -j ACCEPT # LIMITED_LOCAL_NET -> SELF
fi

###########################################################
# 针对特定主机的 INPUT
###########################################################

#if [ "$ZABBIX_IP" ]
#then
#    # Zabbix 相关许可
#    iptables -A INPUT -p tcp -s $ZABBIX_IP --dport 10050 -j ACCEPT # Zabbix -> SELF
#fi

###########################################################
# 否则
# 不符合上述规则的，全部丢弃并记入日志
###########################################################
iptables -A INPUT  -j LOG --log-prefix "drop: "
iptables -A INPUT  -j DROP

###########################################################
# SSH 被锁定的解决办法
# 30秒后自动 rollback，请测试 SSH 后按 Ctrl-C 会完成设置
###########################################################
trap 'finailize && exit 0' 2 # Ctrl-C
echo "In 30 seconds iptables will be automatically reset."
echo "Don't forget to test new SSH connection!"
echo "If there is no problem then press Ctrl-C to finish."
sleep 30
echo "rollback..."
initialize