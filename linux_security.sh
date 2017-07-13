#!/usr/bin/env bash
# usage:
# 1. git clone https://github.com/dongcj/linux-security.git
# 2. cd linux-security && bash ./linux_security.sh

## see 'linux-security.csv'
CSV_COLUMNS=10

## use style
DrawLine 128

## change dir
CUR_DIR=$(echo `dirname $0` | sed -n 's/$/\//p')
cd ${CUR_DIR}

## Check the user
[ `id -u` -ne 0 ] && echo "   Please use root to login!" && exit 1

## import library
. ./lib/functions


## install the necessary python package
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

## check csv file exist
CSVNAME=${0%.*}.csv
[ -f $CSVNAME ] || { echo "   $CSVNAME not found, exit"; exit 1; }
rm -rf ${0%.*}_*.csv


## check csv format
if ! csvlook -l $CSVNAME &>/dev/null; then
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

## csvclean
csvclean $CSVNAME &>/dev/null
[ $? -eq 0 ] || { echo "   $CSVNAME format check failed, exit"; exit 1; }


## find the local rule
echo
echo "${BOLD}# Getting rule for this host..${NORMAL}"
ALL_ADDR_CSV_PATTEN=`echo ${ALL_ADDR[*]} | xargs -n1 | sed -e 's/^/\\</' -e 's/$/\\>/' | tr '\n' '|'`
MY_RULE=`csvgrep -c2 $CSVNAME -r "(${ALL_ADDR_CSV_PATTEN})"`
MY_RULE_CSV=`echo "$MY_RULE" | csvlook`
MY_RULE_CONTENT=`echo "$MY_RULE" | csvgrep -c 1 -r "$ip_regx" -K1`
echo "$MY_RULE_CSV"
echo

echo ALL_ADDR_CSV_PATTEN is "$ALL_ADDR_CSV_PATTEN"
## zero rule for this host
[ -z "$MY_RULE_CONTENT" ] && { echo "No rules for this host, skip~"; echo; exit 0; }

## LOCAL_NET
##


## LIMITED_LOCAL_NET


export whitelist





# save the existing iptables rule before run
echo "the iptables rule will "


# parse the iptables command


# apply iptables rule



