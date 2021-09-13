#!/bin/sh

opt=$1

if [ -z "${opt}" ]; then
    echo "Option miss"
    echo "Useage:" 
    echo "       $0 -l (list gateway connection status)" 
    echo "       $0 gatewayid  (connect gateway through ssh service)" 
fi

if [ "${opt}" = "-l" ]; then
    echo "List Gateways connection status"
    list=`sqlite3 /var/rsshdb.sqlite3 "select key, value from rsshtb where key like '%status/%'"`
    echo "${list}"
    exit 0
fi

gwid=`echo $1 | tr '[a-z]' '[A-Z]'`
echo "GWID:  ${gwid}"

status=`sqlite3 /var/rsshdb.sqlite3 "select value from rsshtb where key like '%status/${gwid}';"`
if [ -n "${status}" ]; then
    #d1=`date -d "${status}" +%s`
    d1=${status}
    d2=`date +%s`
    diff=$(($d2-$d1))
    # TODO if the timezone is not correct 
    if [ $diff -gt 600 ]; then  #10 minutes
        echo "${gwid} status out of date"
        echo "Can't connet to GW"
    fi
    port=`sqlite3 /var/rsshdb.sqlite3 "select value from rsshtb where key like '%port/${gwid}';"`
    if [ -n "${port}" ]; then
        # TODO interaction 
        /usr/bin/ssh -p ${port} root@localhost
    else
        echo "Not found a match port of ${gwid}"
    fi
else
    echo "Not found  match status of ${gwid}"
fi
exit 0
