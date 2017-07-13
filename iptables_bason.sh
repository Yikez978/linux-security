#!/bin/bash

#########################
# �����ͳһ
# ACCEPT : ����
# DROP :   ����
# REJECT : �ܾ�
#########################

# �ٲ��
#
# - A��-- append ����ָ��һ�����ϵ��¹���׷��
# - D��-- delete ָ��������һ�����ϵĹ���ɾ��
# - P��-- policy ָ�����������ߵ�ָ����Ŀ���趨
# - N��-- new - chain �������û�������
# - X��-- delete - chain ָ��ɾ���û�������
# - F ��ʼ����
#
# - p��-- protocol   Э�飨tcp��udp��icmp all��
# - s��-- source IP  ��ַ [ / mask ]Դ��ַ��IP ��ַ����������
# - d��-- destination IP ��ַ [ / mask ] Ŀ���ַ��IP ��ַ����������
# - i��-- in - interface  ����������ָ��
# - o��-- out - interface  ����ȥ����ָ��
# - j��-- JUMP target  ����Ŀ��
# - t��-- table  ��
# - m state -- state  ����״̬������ָ��
# state��NEW��ESTABLISHED��RELATED��INVALID ����ָ����״̬
#��������ת��������ģ�
#########################

# PATH
PATH=/sbin:/usr/sbin:/bin:/usr/bin

###########################################################
# IP ����
###########################################################

# �ڲ����磬�������в���Ҫ����
# LOCAL_NET="xxx.xxx.xxx.xxx/xx"

# �ڲ����Ƶ����緶Χ
# LIMITED_LOCAL_NET="xxx.xxx.xxx.xxx/xx"

# Zabbix IP�������� server �� IP ��ַ��������
# ZABBIX_IP="xxx.xxx.xxx.xxx"

# ���е� IP
# ANY="0.0.0.0/0"

# ���������������������Ϊ�Լ��ľ��������ڵ����� IP
# ALLOW_HOSTS=(
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
# )

# ��ֹ����
# DENY_HOSTS=(
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
#   "xxx.xxx.xxx.xxx"
# )

###########################################################
# �˿ڶ���
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
# ����
###########################################################

# iptables ��ʼ����ɾ�����й���
initialize()
{
    iptables -F # ��ʼ��
    iptables -X # ɾ����
    iptables -Z # ��������ֽڼ�����
    iptables -P INPUT   ACCEPT
    iptables -P OUTPUT  ACCEPT
    iptables -P FORWARD ACCEPT
}

# ������ɺ�Ķ���
finailize()
{
    /etc/init.d/iptables save && # �����O��
    /etc/init.d/iptables restart && # ����
        return 0
    return 1
}

# ����ģʽ
if [ "$1" == "dev" ]
then
    iptables() { echo "iptables $@"; }
    finailize() { echo "finailize"; }
fi

###########################################################
# iptables ��ʼ��
###########################################################
initialize

###########################################################
# ����
###########################################################
iptables -P INPUT   DROP # Ĭ�϶������У�ֻ�����Ҫ�˿�ͨ��
iptables -P OUTPUT  ACCEPT
iptables -P FORWARD DROP

###########################################################
# �������������
###########################################################

# ��������
# ���ػ���
iptables -A INPUT -i lo -j ACCEPT # SELF -> SELF

# ��������
# �������� $LOCAL_NET ����
if [ "$LOCAL_NET" ]
then
    iptables -A INPUT -p tcp -s $LOCAL_NET -j ACCEPT # LOCAL_NET -> SELF
fi

# ��������
# ���� $ALLOW_HOSTS ������ͨ��
if [ "${ALLOW_HOSTS}" ]
then
    for allow_host in ${ALLOW_HOSTS[@]}
    do
        iptables -A INPUT -p tcp -s $allow_host -j ACCEPT # allow_host -> SELF
    done
fi

###########################################################
# $DENY_HOSTS ��������
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
# �ѽ���session�İ�������
###########################################################
iptables -A INPUT  -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT

###########################################################
# ����Ӧ��: ɨ��
###########################################################
iptables -N STEALTH_SCAN # �½� "STEALTH_SCAN" ��
iptables -A STEALTH_SCAN -j LOG --log-prefix "stealth_scan_attack: "
iptables -A STEALTH_SCAN -j DROP

# ����ɨ��İ�����ת�� "STEALTH_SCAN" ��
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
# ����Ӧ��: ���˿�ɨ�裬DOS����
# namap -v -sF �ȶԲ�
###########################################################
iptables -A INPUT -f -j LOG --log-prefix 'fragment_packet:'
iptables -A INPUT -f -j DROP

###########################################################
# ����Ӧ��: "Ping of Death"
###########################################################
# ÿ���Ӧ������10�����ϾͶ���
iptables -N PING_OF_DEATH # �½� "PING_OF_DEATH" ��
iptables -A PING_OF_DEATH -p icmp --icmp-type echo-request \
         -m hashlimit \
         --hashlimit 1/s \
         --hashlimit-burst 10 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_PING_OF_DEATH \
         -j RETURN

# "Ping of Death" ������Ӧ
iptables -A PING_OF_DEATH -j LOG --log-prefix "ping_of_death_attack: "
iptables -A PING_OF_DEATH -j DROP

# ICMP ��ת�� "PING_OF_DEATH" ��
iptables -A INPUT -p icmp --icmp-type echo-request -j PING_OF_DEATH

###########################################################
# ����Ӧ��: SYN Flood Attack
# �������֮���ټ��� SYN_COOKIE ��Ч��
###########################################################
iptables -N SYN_FLOOD # �½� "SYN_FLOOD" ��
iptables -A SYN_FLOOD -p tcp --syn \
         -m hashlimit \
         --hashlimit 200/s \
         --hashlimit-burst 3 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_SYN_FLOOD \
         -j RETURN

# ˵��
# -m hashlimit                       ����ģ��
# --hashlimit 200/s                  ÿ���������� 200
# --hashlimit-burst 3                �������� 3 ��
# --hashlimit-htable-expire 300000   ��¼��Ч�ڣ���λ��ms
# --hashlimit-mode srcip             ��Դ��ַ���� hashlimit
# --hashlimit-name t_SYN_FLOOD       /proc/net/ipt_hashlimit �洢hash��
# -j RETURN                          �������ޣ��򷵻�

# �Գ����İ�����
iptables -A SYN_FLOOD -j LOG --log-prefix "syn_flood_attack: "
iptables -A SYN_FLOOD -j DROP

# SYN ������ SYN_FLOOD ��
iptables -A INPUT -p tcp --syn -j SYN_FLOOD

###########################################################
# ����Ӧ��: HTTP DoS/DDoS Attack
###########################################################
iptables -N HTTP_DOS # �½� "HTTP_DOS" ��
iptables -A HTTP_DOS -p tcp -m multiport --dports $HTTP \
         -m hashlimit \
         --hashlimit 1/s \
         --hashlimit-burst 100 \
         --hashlimit-htable-expire 300000 \
         --hashlimit-mode srcip \
         --hashlimit-name t_HTTP_DOS \
         -j RETURN

# ˵��
# -m hashlimit                       ����ģ��
# --hashlimit 1/s                    ÿ���������� 1
# --hashlimit-burst 100              �������� 100 ��
# --hashlimit-htable-expire 300000   ��¼��Ч�ڣ���λ��ms
# --hashlimit-mode srcip             ��Դ��ַ���� hashlimit
# --hashlimit-name t_HTTP_DOS        /proc/net/ipt_hashlimit �洢hash��
# -j RETURN                          �������ޣ��򷵻�

# �Գ����İ�����
iptables -A HTTP_DOS -j LOG --log-prefix "http_dos_attack: "
iptables -A HTTP_DOS -j DROP

# HTTP �İ�����ת�� HTTP_DOS ��
iptables -A INPUT -p tcp -m multiport --dports $HTTP -j HTTP_DOS

###########################################################
# ����Ӧ��: IDENT port probe
# ���ܻ��ʹĳЩ����Ӧ�½������硺�ʼ�����
###########################################################
iptables -A INPUT -p tcp -m multiport --dports $IDENT -j REJECT --reject-with tcp-reset

###########################################################
# ����Ӧ��: SSH Brute Force
# ���� SSH ���빥��
# 1 ������ 5 �� SSH ����Ϊ "ssh_attack"
# SSH �ܾ����ӣ����������û���������
# ��� SSH ʹ�������½��ʽ��ȡ��ע�Ϳɿ���
###########################################################
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --set
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ssh_brute_force: "
# iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset

###########################################################
# ����Ӧ��: FTP Brute Force
# ���� FTP ���빥��
# 1 ������ 5 �� SSH ����Ϊ "ftp_attack"
# FTP �ܾ����ӣ����������û���������
# ��� FTP ʹ�������½��ʽ��ȡ��ע�Ϳɿ���
###########################################################
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --set
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ftp_brute_force: "
# iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset

###########################################################
# �����������㲥���ಥ��ַ��Ѱַ���鶪��
###########################################################
iptables -A INPUT -d 192.168.1.255   -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 192.168.1.255   -j DROP
iptables -A INPUT -d 255.255.255.255 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 255.255.255.255 -j DROP
iptables -A INPUT -d 224.0.0.1       -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 224.0.0.1       -j DROP

###########################################################
# �������������� INPUT��ANY��
###########################################################

# ICMP: ��Ӧ ping
iptables -A INPUT -p icmp -j ACCEPT # ANY -> SELF

# HTTP, HTTPS
iptables -A INPUT -p tcp -m multiport --dports $SERVICE_PORT -j ACCEPT # ANY -> SELF

# SSH: ���Ҫ���� TRUST_HOSTS ���룬ע�͵����£�
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
# ����ı������緶Χ
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
# ����ض������� INPUT
###########################################################

#if [ "$ZABBIX_IP" ]
#then
#    # Zabbix ������
#    iptables -A INPUT -p tcp -s $ZABBIX_IP --dport 10050 -j ACCEPT # Zabbix -> SELF
#fi

###########################################################
# ����
# ��������������ģ�ȫ��������������־
###########################################################
iptables -A INPUT  -j LOG --log-prefix "drop: "
iptables -A INPUT  -j DROP

###########################################################
# SSH �������Ľ���취
# 30����Զ� rollback������� SSH �� Ctrl-C ���������
###########################################################
trap 'finailize && exit 0' 2 # Ctrl-C
echo "In 30 seconds iptables will be automatically reset."
echo "Don't forget to test new SSH connection!"
echo "If there is no problem then press Ctrl-C to finish."
sleep 30
echo "rollback..."
initialize