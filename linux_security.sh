#!/usr/bin/env bash
# usage:
# 1. git clone https://github.com/dongcj/linux-security.git
# 2. cd linux-security && bash ./cyhd_Security.sh

set -e

## please see linux-security.csv
CSV_COLUMNS=10



## change dir
CUR_DIR=$(echo `dirname $0` | sed -n 's/$/\//p')
cd ${CUR_DIR}

## Check the user
[ `id -u` -ne 0 ] && echo "   Please use root to login!" && exit 1

# install the necessary python package
if grep -iq ubuntu /etc/issue; then
    OS=ubuntu
    PKG_INSTALLER=apt-get
    #apt-get update
elif grep -iq "centos" /etc/issue; then
    OS=centos
    PKG_INSTALLER=yum

fi



## check command
if which csvgrep &>/dev/null; then
    echo "csvkit already installed, good ✓"
else
    # install csvkit python tools
    which pip &>/dev/null || $PKG_INSTALLER -y install python-pip
    pip install csvkit &>/dev/null || { echo "   'pip install csvkit' failed! "; exit 1; }
fi



## console style
SSH="ssh -o StrictHostKeyChecking=no"
BOLD=`tput bold`
SMSO=`tput smso`
UNDERLINE=`tput smul`
NORMAL=`tput sgr0`


## Exit prompt
stty erase '^H'
set -o ignoreeof
trap TrapProcess 2 3
TrapProcess(){
    [ -n "$BG_PID" ] && kill -9 $BG_PID
    echo;  echo; echo "   USER EXIT !!"; echo
    stty erase '^?'
    exit 1
}


## check csv file exist
CSVNAME=${0%.*}.csv
[ -f $CSVNAME ] || { echo "   $CSVNAME not found, exit"; exit 1; }
rm -rf ${0%.*}_error.csv


## check csv format
if ! csvlook -l $CSVNAME 2>/dev/null; then
    echo "   $CSVNAME error"
    if [ -f ${0%.*}_error.csv ]; then
        cat ${0%.*}_error.csv
    fi
    exit 5
fi

## get the local ipaddr
shopt -s extglob
IFACES=(/proc/sys/net/ipv4/conf/!(all|default|lo|v*|docker*|br*))
shopt -u extglob

for iface in "${IFACES[@]}"; do
    ADDR=$(ip -4 -o addr show dev ${iface##*/} | awk '{print $4}' | awk -F '/' '{print $1}')
    ALL_ADDR=(${ALL_ADDR[*]} $ADDR)
done

## print the csv content
echo "${BOLD}Dealing csv file..${NORMAL}";
csvclean $CSVNAME &>/dev/null
[ $? -eq 0 ] || { echo "   $CSVNAME format check failed, exit"; exit 1; }

echo
ip_regx="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5]))\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5]))$"
ALL_ADDR_CSV_PATTEN=`echo ${ALL_ADDR[*]} | tr ' ' '|'`


## get the local rule
# SOURCEIP=`csvgrep -c2 -r "(${ALL_ADDR_CSV_PATTEN})" linux_security.csv | csvcut -c SIP | csvgrep -c 1 -r "$ip_regx" -K1`
echo "${BOLD}Getting rule for this host..${NORMAL}"
LOCAL_RULE=`csvgrep -c2 linux_security.csv -r "(${ALL_ADDR_CSV_PATTEN})"`
LOCAL_RULE_CSV=`echo "$LOCAL_RULE" | csvlook`
LOCAL_RULE_CONTENT=`echo "$LOCAL_RULE" | csvgrep -c 1 -r "$ip_regx" -K1`
echo "$LOCAL_RULE_CSV"
echo


## LOCAL_NET
##


## LIMITED_LOCAL_NET


export whitelist





# save the existing iptables rule before run
echo "the iptables rule will "


# parse the iptables command


# apply iptables rule


