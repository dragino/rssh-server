#!/bin/sh

opt=$1
moduleID=$2
gatewayID=""
port=""

Blue='\033[0;34m'
Red='\033[0;31m'    # Red
Green='\033[0;32m'  # Green
Unset='\033[0m'     # No Color

searchForGatewayID(){
    gatewayID=`sqlite3 /var/rsshdb.sqlite3 "select key, value from rsshtb where key like '%status/%$moduleID'" | cut -d "/" -f 4 | cut -d "|" -f 1`
}

setStatus(){
    status=`sqlite3 /var/rsshdb.sqlite3 "select value from rsshtb where key like '%status/${gatewayID}';"`
    if [ -n "${status}" ]; then
        d1=${status}
        d2=`date +%s`
        diff=$(($d2-$d1))
        if [ $diff -gt 600 ]; then  #10 minutes
            echo -e "Connection impossible, la dernière MAJ date de plus de $((diff/60))min (Refresh toutes les 10min)"
            exit 0
        fi
    else
            echo "Connection impossible, le dispositif n'a jamais communiqué"
    fi
}

setPort(){
    port=`sqlite3 /var/rsshdb.sqlite3 "select value from rsshtb where key like '%port/${gatewayID}';"`
    if [ -z "${port}" ]; then
        echo "Pas de port trouvé"
        exit 0
    fi
}

if [ "$#" -eq 0 ]; then
    echo "Usage:" 
    echo "       gateway -l : Liste les gateway ayant déjà communiquées (l: list)" 
    echo "       gateway -i moduleID : Connection SSH à la gateway (i: interract)" 
    echo "       gateway -c moduleID : Retourne la source internet (c: connectivity)" 
    echo "       gateway -r moduleID : Reboot de la gateway (c: connectivity)" 
    exit 0
fi

if [ "${opt}" = "-l" ] && [ "$#" -eq 1 ]; then
    list=`sqlite3 /var/rsshdb.sqlite3 "select key, value from rsshtb where key like '%status/%'"`
    echo "${list}"
    exit 0
elif [ "${opt}" = "-i" ] && [ "$#" -eq 2 ]; then
    searchForGatewayID
    setStatus
    setPort
    sshpass -p dragino /usr/bin/ssh -p ${port} -o StrictHostKeyChecking=no root@localhost
    exit 0
elif [ "${opt}" = "-c" ] && [ "$#" -eq 2 ]; then
    searchForGatewayID
    setStatus
    setPort
    interface=$(sshpass -p dragino /usr/bin/ssh -p ${port} -o StrictHostKeyChecking=no root@localhost "ip route|grep default|cut -d ' ' -f 5")
        if [[ $interface == "wlan0-2" ]] ; then
            echo "${Green} Connectée en Wifi ${Unset}"
        elif [[ $interface == "eth1" ]] ; then
            echo "${Green} Connectée en Ethernet ${Unset}"
        elif [[ $interface == "3g-cellular" ]]; then
            echo -e  "${Green}Connectée en 4G ${Unset}"
        fi
    exit 0
elif [ "${opt}" = "-r" ] && [ "$#" -eq 2 ]; then
    echo "${Green} Reboot de la gateway: ${Unset}"
    searchForGatewayID
    setStatus
    setPort
    sshpass -p dragino /usr/bin/ssh -p ${port} -tt root@localhost "reboot"
    exit 0
else
    echo "Arguments invalides"
fi
