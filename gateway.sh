#!/bin/sh

_wireguarddb="/var/wireguarddb.sqlite3"
_wireguardtb="wireguardtb"

_rsshdb="/var/rsshdb.sqlite3"
_rsshtb="rsshtb"

_wireguard_config_file="/etc/wireguard/wg0.conf"

addWireguardDevice() {
    argumentsInvalids "addWireguardDevice" 2 "$#"
    _addWireguardDevice_loraDevEUI=$1
    _addWireguardDevice_publicKey=$2
    _addWireguardDevice_moduleID=$(printf '%s' "$_addWireguardDevice_loraDevEUI" | cut -c 9-16)

    # Contrôle si le dispositif existe déjà ?
    _addWireguardDevice_ip=$(sqlite3 $_wireguarddb "select key, value from $_wireguardtb where key like '//ip/$_addWireguardDevice_loraDevEUI/'" | cut -d "/" -f 4 | cut -d "|" -f 1)
    if [ -n "$_addWireguardDevice_ip" ]; then
        # Le dispositif existe
        echo "deviceAlreadyExist"
        exit 0
    else
        # Récupérer la dernière IP utilisée (SQLite) - ligne //wireguard/lastIP | IP (SQLite)
        _addWireguardDevice_ip=$(sqlite3 $_wireguarddb "select value from $_wireguardtb where key like '%wireguard/lastIP%'" | cut -d "/" -f 4 | cut -d "|" -f 1)
        # ip V4
        _addWireguardDevice_firstFragment=$(echo "$_addWireguardDevice_ip" | cut -d "." -f 1)
        _addWireguardDevice_secondFragment=$(echo "$_addWireguardDevice_ip" | cut -d "." -f 2)
        _addWireguardDevice_thirdFragment=$(echo "$_addWireguardDevice_ip" | cut -d "." -f 3)
        _addWireguardDevice_fourthFragment=$(echo "$_addWireguardDevice_ip" | cut -d "." -f 4)
        _addWireguardDevice_fourthFragment_incremented=$((_addWireguardDevice_fourthFragment + 1))
        # todo : gérer la fin de plage
        # Reconstruction de la nouvelle IP
        _addWireguardDevice_newIP="${_addWireguardDevice_firstFragment}.${_addWireguardDevice_secondFragment}.${_addWireguardDevice_thirdFragment}.${_addWireguardDevice_fourthFragment_incremented}"

        # Ajouter à la conf wg0.conf la nouvelle entrée
        appendDataToWireguardConfigFile "$_addWireguardDevice_moduleID" "$_addWireguardDevice_publicKey" "$_addWireguardDevice_newIP"

        # Ajouter la ligne //ip/loraDevEUI | IP (SQLite)
        sudo sqlite3 $_wireguarddb "INSERT INTO $_wireguardtb (key, value) VALUES ('//ip/$_addWireguardDevice_loraDevEUI/', '$_addWireguardDevice_newIP')"

        # Mettre à jour la dernière IP utilisée
        sudo sqlite3 $_wireguarddb "INSERT OR REPLACE INTO $_wireguardtb (key, value) VALUES ('//wireguard/lastIP/', '$_addWireguardDevice_newIP')"
        # Ajouter la ligne //port/loraDevEUI | PORT (en fonction draginoV1 ou v2) (SQLite)

        _addWireguardDevice_port="22"
        _addWireguardDevice_twoFirstChars=$(printf '%s' "$_addWireguardDevice_moduleID" | cut -c 1-2)
        if [ "$_addWireguardDevice_moduleID" = "ff" ]; then
            _addWireguardDevice_port="2222"
        fi

        sudo sqlite3 $_wireguarddb "INSERT INTO $_wireguardtb (key, value) VALUES ('//port/$_addWireguardDevice_loraDevEUI/', '$_addWireguardDevice_port')"
        restartWireguardService
        echo "success"
        exit 0
    fi
}

appendDataToWireguardConfigFile() {
    argumentsInvalids "appendDataToWireguardConfigFile" 3 "$#"
    _appendDataToWireguardConfigFile_moduleID=$1
    _appendDataToWireguardConfigFile_publicKey=$2
    _appendDataToWireguardConfigFile_newIP=$3

    echo "[Peer]" | sudo tee -a $_wireguard_config_file >/dev/null
    echo "## $_appendDataToWireguardConfigFile_moduleID" | sudo tee -a $_wireguard_config_file >/dev/null
    echo "PublicKey = $_appendDataToWireguardConfigFile_publicKey" | sudo tee -a $_wireguard_config_file >/dev/null
    echo "AllowedIPs = $_appendDataToWireguardConfigFile_newIP" | sudo tee -a $_wireguard_config_file >/dev/null
    echo " " | sudo tee -a $_wireguard_config_file >/dev/null
}

startWireguardService() {
    sudo systemctl start wg-quick@wg0.service
}

stopWireguardService() {
    sudo systemctl stop wg-quick@wg0.service
}

restartWireguardService() {
    sudo systemctl restart wg-quick@wg0.service
}

getWireguardService() {
    systemctl status wg-quick@wg0.service
}

retrieveWireguardIP() {
    argumentsInvalids "retrieveWireguardIP" 1 "$#"
    _retrieveWireguardIP_moduleID=$1
    # recherche de l'IP par module dans la table SQLite
    _retrieveWireguardIP_ip=$(sqlite3 $_wireguarddb "select value from $_wireguardtb where key like '//ip/%$_retrieveWireguardIP_moduleID%'" | cut -d "/" -f 4 | cut -d "|" -f 1)
    if [ -n "$_retrieveWireguardIP_ip" ]; then
        # on affiche l'IP
        displayValue "$_retrieveWireguardIP_ip"
    else # Sinon on retourne "noDeviceFound"
        noDeviceFound
    fi
}

retrieveConnectivityFromWireguardOrRssh() { # noDeviceFound or noResponseFromTheDevice or element of [wifi, ethernet, 4g, unknown]
    argumentsInvalids "retrieveConnectivityFromWireguardOrRssh" 1 "$#"
    _retrieveConnectivityFromWireguardOrRssh_moduleID=$1
    # recherche de l'IP par module dans la table SQLite
    _retrieveConnectivityFromWireguardOrRssh_ip=$(sqlite3 $_wireguarddb "select key, value from $_wireguardtb where key like '%ip/%$moduleID%'" | cut -d "/" -f 4 | cut -d "|" -f 1)
    if [ -n "$_retrieveConnectivityFromWireguardOrRssh_ip" ]; then
        # Si IP retournée on continue, connection SSH et réccuépration de la source de la connectivité
        _retrieveConnectivityFromWireguardOrRssh_port=$(getPort "$_retrieveConnectivityFromWireguardOrRssh_moduleID")
        _retrieveConnectivityFromWireguardOrRssh_interface=$(sshpass -p dragino /usr/bin/ssh -o StrictHostKeyChecking=no -p "$_retrieveConnectivityFromWireguardOrRssh_port" root@"$_retrieveConnectivityFromWireguardOrRssh_ip" "ip route|grep default|cut -d ' ' -f 5")
        returnReadableConnectivity "$_retrieveConnectivityFromWireguardOrRssh_interface"
    else # Sinon on retourne "noDeviceFound"
        retrieveConnectivityFromRSSH "$_retrieveConnectivityFromWireguardOrRssh_moduleID"
    fi
}

retrieveConnectivityFromRSSH() { # noDeviceFound or noResponseFromTheDevice or element of [wifi, ethernet, 4g, unknown]
    argumentsInvalids "retrieveConnectivityFromRSSH" 1 "$#"
    _retrieveConnectivityFromRSSH_moduleID=$1
    # Recherche de la dernière trace de communication dans la table SQLite par module
    _retrieveConnectivityFromRSSH_lastCommunicationTimestamp=$(sqlite3 $_rsshdb "select value from $_rsshtb where key like '%status/%$_retrieveConnectivityFromRSSH_moduleID';")
    if [ -n "$_retrieveConnectivityFromRSSH_lastCommunicationTimestamp" ]; then
        _retrieveConnectivityFromRSSH_nowTimestamp=$(date +%s)
        _retrieveConnectivityFromRSSH_diff=$((_retrieveConnectivityFromRSSH_nowTimestamp - _retrieveConnectivityFromRSSH_lastCommunicationTimestamp))
        if [ "$_retrieveConnectivityFromRSSH_diff" -gt 1200 ]; then # Si le dispositif n'a pas communiqué depuis plus de 20 minutes (deux cycles de communication: 10min) quelque chose ne va pas
            noResponseFromTheDeviceSince "$_retrieveConnectivityFromRSSH_lastCommunicationTimestamp"
        else
            # On récupère le le numéro de port
            _retrieveConnectivityFromRSSH_port=$(getPort "$_retrieveConnectivityFromRSSH_moduleID")
            if [ -n "$_retrieveConnectivityFromRSSH_port" ]; then
                _retrieveConnectivityFromRSSH_interface=$(sshpass -p dragino /usr/bin/ssh -p "${_retrieveConnectivityFromRSSH_port}" -o StrictHostKeyChecking=no root@localhost "ip route|grep default|cut -d ' ' -f 5")
                returnReadableConnectivity "$_retrieveConnectivityFromRSSH_interface"
            else
                noResponseFromTheDevice
            fi
        fi
    else # Sinon on retourne "noDeviceFound"
        noDeviceFound
    fi
}

returnAlreadyConnectedGateway() {
    argumentsInvalids "returnAlreadyConnectedGateway" 1 "$#"
    _returnAlreadyConnectedGateway_connectionType=$1
    if [ "$_returnAlreadyConnectedGateway_connectionType" = "rssh" ]; then
        _returnAlreadyConnectedGateway_list=$(sqlite3 $_rsshdb "select key, value from $_rsshtb where key like '%port/%'")
    else
        _returnAlreadyConnectedGateway_list=$(sqlite3 $_wireguarddb "select key, value from $_wireguardtb where key like '//ip/%'")
    fi
    displayValue "$_returnAlreadyConnectedGateway_list"
}

retrieveAndInitiateSSHConnection() {
    argumentsInvalids "retrieveAndInitiateSSHConnection" 1 "$#"
    # recherche de l'IP par module dans la table SQLite
    _retrieveAndInitiateSSHConnection_moduleID=$1
    _retrieveAndInitiateSSHConnection_command=$2
    _retrieveAndInitiateSSHConnection_ip=$(sqlite3 $_rsshdb "select key, value from $_rsshtb where key like '%ip/%$_retrieveAndInitiateSSHConnection_moduleID'" | cut -d "/" -f 4 | cut -d "|" -f 1)
    if [ -n "$_retrieveAndInitiateSSHConnection_ip" ]; then
        # Si IP retournée on continue, connection SSH et réccuépration de la source de la connectivité
        _retrieveAndInitiateSSHConnection_port=$(getPort "$_retrieveAndInitiateSSHConnection_moduleID")
        connectOrSendSSHCommand "$_retrieveAndInitiateSSHConnection_port" "$_retrieveAndInitiateSSHConnection_ip" "$_retrieveAndInitiateSSHConnection_command"
    else # Sinon on cherche par RSSH
        _retrieveAndInitiateSSHConnection_lastCommunicationTimestamp=$(sqlite3 $_rsshdb "select value from $_rsshtb where key like '%status/%$_retrieveAndInitiateSSHConnection_moduleID';")
        _retrieveAndInitiateSSHConnection_ip="localhost"
        if [ -n "$_retrieveAndInitiateSSHConnection_lastCommunicationTimestamp" ]; then
            _retrieveAndInitiateSSHConnection_nowTimestamp=$(date +%s)
            _retrieveAndInitiateSSHConnection_diff=$((_retrieveAndInitiateSSHConnection_nowTimestamp - _retrieveAndInitiateSSHConnection_lastCommunicationTimestamp))
            if [ $_retrieveAndInitiateSSHConnection_diff -gt 1200 ]; then # Si le dispositif n'a pas communiqué depuis plus de 20 minutes (deux cycles de communication: 10min) quelque chose ne va pas
                noResponseFromTheDeviceSince "$_retrieveAndInitiateSSHConnection_lastCommunicationTimestamp"
            else
                # On récupère le le numéro de port
                _retrieveAndInitiateSSHConnection_port=$(getPort "$_retrieveAndInitiateSSHConnection_moduleID")
                connectOrSendSSHCommand "$_retrieveAndInitiateSSHConnection_port" "$_retrieveAndInitiateSSHConnection_ip" "$_retrieveAndInitiateSSHConnection_command"
            fi
        else # Sinon on retourne "noDeviceFound"
            noDeviceFound
        fi
    fi
}

connectOrSendSSHCommand() {
    _connectOrSendSSHCommand_port=$1
    _connectOrSendSSHCommand_ip=$2
    _connectOrSendSSHCommand_command=$3
    if [ -n "$_connectOrSendSSHCommand_command" ]; then
        initiateSSHConnection "$_connectOrSendSSHCommand_port" "$_connectOrSendSSHCommand_ip"
    else
        sendSSHCommand "$_connectOrSendSSHCommand_port" "$_connectOrSendSSHCommand_ip" "$_connectOrSendSSHCommand_command"
    fi
}

initiateSSHConnection() {
    _initiateSSHConnection_port=$1
    _initiateSSHConnection_ip=$2
    sshpass -p dragino /usr/bin/ssh -o StrictHostKeyChecking=no -p "$_initiateSSHConnection_port" root@"$_initiateSSHConnection_ip"
    exit 0
}

sendSSHCommand() {
    _sendSSHCommand_port=$1
    _sendSSHCommand_ip=$2
    _sendSSHCommand_command=$3
    sshpass -p dragino /usr/bin/ssh -p "$_sendSSHCommand_port" -tt root@"$_sendSSHCommand_ip" "$_sendSSHCommand_command"
}

getPort() {
    _getPort_moduleID=$1
    _getPort_port=$(sqlite3 $_rsshdb "select value from $_rsshtb where key like '%port/%$_getPort_moduleID';")
    if [ -n "$_getPort_port" ]; then
        echo "$_getPort_port"
    else
        noResponseFromTheDevice
    fi
}

returnReadableConnectivity() {
    argumentsInvalids "returnReadableConnectivity" 1 "$#"
    _returnReadableConnectivity_source=$1
    _returnReadableConnectivity_networkSource="unknown"
    if [ "$_returnReadableConnectivity_source" = "wlan0-2" ]; then
        _returnReadableConnectivity_networkSource="wifi"
    elif [ "$_returnReadableConnectivity_source" = "eth1" ]; then
        _returnReadableConnectivity_networkSource="ethernet"
    elif [ "$_returnReadableConnectivity_source" = "3g-cellular" ]; then
        _returnReadableConnectivity_networkSource="4g"
    fi
    displayValue $_returnReadableConnectivity_networkSource
}

displayValue() {
    echo "$1"
    exit 0
}

noDeviceFound() {
    # le dispositif n'est déclaré ni sur wireguard ni sur rssh
    displayValue "deviceDoesNotExist"
}

noResponseFromTheDevice() {
    # le dispositif n'est déclaré ni sur wireguard ni sur rssh
    displayValue "noResponseFromTheDevice"
}

noResponseFromTheDeviceSince() {
    # le dispositif n'a pas communiqué depuis un moment
    displayValue "noResponseFromTheDeviceSince:$1"
}

argumentsInvalids() {
    _argumentsInvalids_functionName=$1
    _argumentsInvalids_minExpectedNumberOfArgs=$2
    _argumentsInvalids_numberOfArgs=$3
    if [ "$_argumentsInvalids_numberOfArgs" -lt "$_argumentsInvalids_minExpectedNumberOfArgs" ]; then
        echo "$_argumentsInvalids_functionName: invalidArguments"
        exit 0
    fi
}

## "Main"
opt=$1
moduleID=$2
if [ "$#" -eq 0 ] || [ "${opt}" = "-h" ] || [ "${opt}" = "--help" ]; then
    echo "Usage:"
    echo "       gateway -l --list : Liste les gateway ayant déjà communiquées (l: list)"
    echo "       gateway -i --interract moduleID : Connection SSH à la gateway (i: interract)"
    echo "       gateway -c --connectivity moduleID : Retourne la source internet (c: connectivity)"
    echo "       gateway -r --reboot moduleID : Reboot de la gateway (c: connectivity)"
    echo "       gateway -a --addWireguard loraDevEUI publickey : création du lien wireguard"
    echo "       gateway -g --getWireguardIP moduleID : création du lien wireguard"
    echo "       gateway -h --help : affichage de l'aide"
    exit 0
fi

if [ "${opt}" = "-l" ] || [ "${opt}" = "--listRssh" ] && [ "$#" -eq 1 ]; then
    returnAlreadyConnectedGateway "rssh"
elif [ "${opt}" = "-lw" ] || [ "${opt}" = "--listWireguard" ] && [ "$#" -eq 1 ]; then
    returnAlreadyConnectedGateway "wireguard"
elif [ "${opt}" = "-i" ] || [ "${opt}" = "--interract" ] && [ "$#" -eq 2 ]; then
    retrieveAndInitiateSSHConnection "$moduleID"
elif [ "${opt}" = "-c" ] || [ "${opt}" = "--connectivity" ] && [ "$#" -eq 2 ]; then
    retrieveConnectivityFromWireguardOrRssh "$moduleID"
elif [ "${opt}" = "-r" ] || [ "${opt}" = "--reboot" ] && [ "$#" -eq 2 ]; then
    retrieveAndInitiateSSHConnection "$moduleID" "reboot"
elif [ "${opt}" = "-a" ] || [ "${opt}" = "--addWireguard" ] && [ "$#" -eq 3 ]; then
    addWireguardDevice "$2" "$3"
elif [ "${opt}" = "-g" ] || [ "${opt}" = "--getWireguardIP" ] && [ "$#" -eq 2 ]; then
    retrieveWireguardIP "$moduleID"
else
    echo "Arguments invalides"
fi
