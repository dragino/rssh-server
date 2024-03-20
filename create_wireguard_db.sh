#!/bin/sh
_wireguarddb="/var/wireguarddb.sqlite3"
_wireguardtb="wireguardtb"

# # create table
sudo sqlite3 /var/wireguarddb.sqlite3  "CREATE TABLE IF NOT EXISTS wireguardtb(key VARCHAR(256), value VARCHAR(512), PRIMARY KEY(key));"

# # initiate first ip
sudo sqlite3 /var/wireguarddb.sqlite3 "INSERT INTO wireguardtb (key, value) VALUES ('//wireguard/lastIP/', '10.0.0.13')"

# # purge
sudo sqlite3 /var/wireguarddb.sqlite3 "DELETE FROM wireguardtb"

moduleID=('')
ip=('')
port=('')

# populate db with known values
for i in "${!moduleID[@]}"
do
    _addWireguardDevice_loraDevEUI=${moduleID[$i]}
    _addWireguardDevice_newIP=${ip[$i]}
    _addWireguardDevice_port=${port[$i]}

    echo "$_addWireguardDevice_loraDevEUI, $_addWireguardDevice_newIP, $_addWireguardDevice_port"
    sudo sqlite3 $_wireguarddb "INSERT INTO $_wireguardtb (key, value) VALUES ('//ip/$_addWireguardDevice_loraDevEUI/', '$_addWireguardDevice_newIP')"
    sudo sqlite3 $_wireguarddb "INSERT INTO $_wireguardtb (key, value) VALUES ('//port/$_addWireguardDevice_loraDevEUI/', '$_addWireguardDevice_port')"
done
