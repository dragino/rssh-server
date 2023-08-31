#!/bin/sh

id=""

function getConnectivity(){
   ./connectivity.sh $id
}

function reboot(){
   ./reboot.sh $id
}


# ##
# # Color  Variables
# ##
# green='\e[32m'
# blue='\e[34m'
# clear='\e[0m'

# ##
# # Color Functions
# ##

# ColorGreen(){
# 	echo -ne $green$1$clear
# }
# ColorBlue(){
# 	echo -ne $blue$1$clear
# }

connectivityMenu(){
echo "Saisir le moduleID"
read id
if [ -z "${id}" ];then 
    menu 
else 
    getConnectivity
    connectivityMenu
fi
}
rebootMenu(){
echo "Saisir le moduleID"
read id
if [ -z "${id}" ];then 
    menu 
else 
    reboot
    rebootMenu
fi
}



menu(){
echo " Connectivité des gateways dragino
    '1) Source internet de la gateway
    '2) Reboot de la gateway
    '0) Sortir
Choisir une option: "
        read a
        case $a in
	        1) connectivityMenu ; menu ;;
	        2) rebootMenu ; menu ;;
		0) exit 0 ;;
		*) echo -e $red"Option invalide."$clear; menu;;
        esac
}

menu