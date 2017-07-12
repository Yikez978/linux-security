#!/usr/bin/env bash
# usage:
# 1. git clone https://github.com/dongcj/linux-security.git
# 2. cd linux-security && bash ./cyhd_Security.sh


##
export whitelist

## change dir
CUR_DIR=$(echo `dirname $0` | sed -n 's/$/\//p')
cd ${CUR_DIR}

## Check the user
[ `id -u` -ne 0 ] && echo "   Please use root to login!" && exit 1

# install the necessary python package
if grep -iq ubuntu /etc/issue; then
    OS=ubuntu
    PKG_INSTALLER=apt-get
    apt-get update
elif grep -iq "centos" /etc/issue; then
    OS=centos
    PKG_INSTALLER=yum

fi

# install csvkit python tools
if which pip &>/dev/null || $PKG_INSTALLER -y install python-pip
pip install csvkit &>/dev/null || { echo "   pip install csvkit failed!'"; exit 1; }

## check command
which csvgrep &>/dev/null || { echo "   please use 'pip install csvkit' manual"; exit 1; }


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
CSVNAME=${0/.*//}.csv
[ -f $CSVNAME ] || { echo "   $CSVNAME not found, exit"; exit 1; }


## check csv format
# 4 columns check
DELIMETER=','
CSV_COLUMNS=`awk -F"$DELIMETER" '{print NF}' $CSVNAME`
[ -z `echo $CSV_COLUMNS | tr -d 4` ] || { echo "   $CSVNAME format check failed, exit"; exit 1; }


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

    # check if there are the same rules

done





# save the existing iptables rule before run
echo "the iptables rule will "


# parse the iptables command


# apply iptables rule


