#!/usr/bin/env bash
# usage:
# 1. git clone https://github.com/dongcj/linux-security.git
# 2. bash ./cyhd_Security.sh


## change dir
CUR_DIR=$(echo `dirname $0` | sed -n 's/$/\//p')
cd ${CUR_DIR}

## Check the user
[ `id -u` -ne 0 ] && echo "   Please use root to login!" && exit 1

# install the necessary python package
pip install csvkit || { echo "   pip install csvkit failed!'"; exit 1; }

## check command
which csvgrep &>/dev/null || { echo "   please use 'pip install csvkit first!'"; exit 1; }

## centos release file
RELEASE_FILE=/etc/redhat-release
# get the dist name
DIST=$(uname -r | sed -r  's/^.*\.([^\.]+)\.[^\.]+$/\1/')


## check release file
[ -f "$RELEASE_FILE" ] || { echo "   Not RedHat/CentOS Linux? exit"; exit 1; }

OS_DISTRIBUTION=`sed -n '1p' $RELEASE_FILE | awk '{OFS=" ";print $1" "$2" "}' | xargs`
[ "$OS_DISTRIBUTION" != "Red Hat" -a "$OS_DISTRIBUTION" != "CentOS release" ] && { \
    echo "   Not RedHat/CentOS Linux? exit"; exit 1; }

[ "$OS_FAMILY" != "Linux" ] && echo "   Not RedHat/CentOS Linux? exit" && exit 1
OS_VERSION=`cat $RELEASE_FILE | awk '{print $((NF-1))}'`
[ ${OS_VERSION:0:1} -ge 6 ] 2>/dev/null || { echo "   RedHat/CentOS version must greater than 6, exit"; exit 1; }


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
CSVNAME=${0%.}.csv
[ -f $CSVNAME ] || { echo "   $CSVNAME not found, exit"; exit 1; }


## check csv format
# Check the ',' numbers
DELIMETER=','
CSV_COLUMNS=`awk -F"$DELIMETER" '{print NF}' $CSVNAME`
echo $CSV_COLUMNS | grep -q 4 || { echo "   $CSVNAME format check failed, exit"; exit 1; }


## get the local ipaddr
shopt -s extglob
IFACES=(/proc/sys/net/ipv4/conf/!(all|default|lo|v*|docker*|br*))
shopt -u extglob

DIST=$(uname -r | sed -r  's/^.*\.([^\.]+)\.[^\.]+$/\1/')
ADDR=''

for iface in "${IFACES[@]}"; do
    ADDR="$( \
        /sbin/ip -4 -o addr show dev "${iface##*/}" \
        | awk '{split($4,a,"."); print a[1] "." a[2] "." a[3] "." a[4]}' \
    )"
    ALL_ADDR=($ALL_ADDR $ADDR)
done


## check local ip in csv
for i in ${ALL_ADDR[*]}; do

    echo $i

done




