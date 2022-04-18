#!/usr/bin/env bash

# Add new IP-host pair to /etc/hosts.

if [[ "$1" && "$2" ]]
then
    IP=$1
    LNMP=$2

    if [ -n "$(grep [^\.]$LNMP /etc/hosts)" ]
        then
            echo "$LNMP already exists:";
            echo $(grep [^\.]$LNMP /etc/hosts);
        else
            sudo sed -i "/#### LNMP-SITES-BEGIN/c\#### LNMP-SITES-BEGIN\\n$IP\t$LNMP" /etc/hosts

            if ! [ -n "$(grep [^\.]$LNMP /etc/hosts)" ]
                then
                    echo "Failed to add $LNMP.";
            fi
    fi
else
    echo "Error: missing required parameters."
    echo "Usage: "
    echo "  addhost ip domain"
fi
