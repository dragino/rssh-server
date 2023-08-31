#!/bin/sh

opt=$1
moduleID=$2
gatewayID=""
port=""

searchForGatewayID(){
    gatewayID=`sqlite3 /var/rsshdb.sqlite3 "select key, value from rsshtb where key like '%status/%$moduleID'" | cut -d "/" -f 4 | cut -d "|" -f 1`
    echo "GatewayID:  ${gatewayID}"
}

setStatus(){
    status=`sqlite3 /var/rsshdb.sqlite3 "select value from rsshtb where key like '%status/${gatewayID}';"`
    if [ -n "${status}" ]; then
        d1=${status}
        d2=`date +%s`
        diff=$(($d2-$d1))
        # TODO if the timezone is not correct 
        if [ $diff -gt 600 ]; then  #10 minutes
            echo "Connection impossible, la dernière MAJ date de plus de 10 min"
            exit 0
        fi
    else
            echo "Connection impossible, le dispositif n'a jamais communiqué"
    fi
}

setPort(){
    port=`sqlite3 /var/rsshdb.sqlite3 "select value from rsshtb where key like '%port/${gatewayID}';"`
    if [ -n "${port}" ]; then
        echo "Port: {$port}"
    else
        echo "Pas de port trouvé"
        exit 0
    fi
}

if [ "$#" -eq 0 ]; then
    echo "Usage:" 
    echo "       $0 -l : Liste les gateway ayant déjà communiquées (l: list)" 
    echo "       $0 -i moduleID : Connection SSH à la gateway (i: interract)" 
    echo "       $0 -c moduleID : Retourne la source internet (c: connectivity)" 
    echo "       $0 -r moduleID : Reboot de la gateway (c: connectivity)" 
    exit 0
fi

if [ "${opt}" = "-l" ] && [ "$#" -eq 1 ]; then
    echo "Liste les gateway ayant déjà communiquées"
    list=`sqlite3 /var/rsshdb.sqlite3 "select key, value from rsshtb where key like '%status/%'"`
    echo "${list}"
    exit 0
elif [ "${opt}" = "-i" ] && [ "$#" -eq 2 ]; then
    echo "Connection SSH:"
    searchForGatewayID
    setStatus
    setPort
    sshpass -p dragino /usr/bin/ssh -p ${port} root@localhost
    exit 0
elif [ "${opt}" = "-c" ] && [ "$#" -eq 2 ]; then
    echo "Source internet:"
    searchForGatewayID
    setStatus
    setPort
    interface=$(sshpass -p dragino /usr/bin/ssh -p ${port} root@localhost "ip route|grep default|cut -d ' ' -f 5")
        if [[ $interface == "wlan0-2" ]] ; then
            echo "Connectée en Wifi"
        elif [[ $interface == "eth1" ]] ; then
            echo "Connectée en Ethernet"
        elif [[ $interface == "3g-cellular" ]]; then
            echo "Connectée en 4G"
        fi
    exit 0
elif [ "${opt}" = "-r" ] && [ "$#" -eq 2 ]; then
    echo "Reboot de la gateway:"
    searchForGatewayID
    setStatus
    setPort
    sshpass -p dragino /usr/bin/ssh -p ${port} -tt root@localhost "reboot"
    exit 0
else
    echo "Arguments invalides"
fi
