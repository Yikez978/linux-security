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
    #apt-get update
elif grep -iq "centos" /etc/issue; then
    OS=centos
    PKG_INSTALLER=yum

fi

# install csvkit python tools
which pip &>/dev/null || $PKG_INSTALLER -y install python-pip
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
CSVNAME=${0%.*}.csv
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


for iface in "${IFACES[@]}"; do
    ADDR=$(ip -4 -o addr show dev ${iface##*/} | awk '{print $4}' | awk -F '/' '{print $1}')
    ALL_ADDR=(${ALL_ADDR[*]} $ADDR)
done

## print the csv content
echo "${BOLD}  Dealing csv file..${NORMAL}"
csvclean $CSVNAME &>/dev/null
csvlook -l $CSVNAME
[ $? -eq 0 ] || { echo "   $CSVNAME format check failed, exit"; exit 1; }
echo
ip_regx="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5]))\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2([0-4][0-9]|5[0-5]))$"

ALL_ADDR_CSV_PATTEN=`echo $ALL_ADDR | tr ' ' '|'`

    # loop the csv SourceIP
    SOURCEIP=csvgrep -c2 linux_security.csv | csvcut -c SourceIP | csvgrep -c 1 -r "$ip_regx" -K1

    for sip in $SOURCEIP; do



    done

    # check if there are the same rules






# save the existing iptables rule before run
echo "the iptables rule will "


# parse the iptables command


# apply iptables rule


