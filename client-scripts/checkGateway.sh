#!/bin/sh

id=""

function getConnectivity(){
   ./connectivity.sh $id
}

function reboot(){
   ./reboot.sh $id
}


##
# Color  Variables
##
Blue='\033[0;34m'
Red='\033[0;31m'   
Green='\033[0;32m' 
Unset='\033[0m'    

connectivityMenu(){
echo "${Blue}Saisir le moduleID${Unset} (0 : retour au menu)"
read id
if [ -z "${id}" ] || [ $id == "0" ];then 
    menu 
else    
    getConnectivity
    connectivityMenu
fi
}
rebootMenu(){
echo "${Blue}Saisir le moduleID${Unset} (0 : retour au menu)"
read id
if [ -z "${id}" ] || [ $id == "0" ];then 
    menu 
else 
    reboot
    rebootMenu
fi
}



menu(){
echo "${Blue}Connectivité des gateways dragino${Unset}
    ${Blue}1)${Unset} Source internet de la gateway
    ${Blue}2)${Unset} Reboot de la gateway
    ${Blue}0)${Unset} Sortir
${Green}Choisir une option:${Unset}"
        read a
        case $a in
	        1) connectivityMenu ; menu ;;
	        2) rebootMenu ; menu ;;
		0) exit 0 ;;
		*) echo -e $Red"Option invalide."$Unset; menu;;
        esac
}

menu