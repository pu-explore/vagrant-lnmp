#!/usr/bin/env bash

# Remove any Lnmp entries from /etc/hosts and prepare for adding new ones.

sudo sed -i '/#### LNMP-SITES-BEGIN/,/#### LNMP-SITES-END/d' /etc/hosts

printf "#### LNMP-SITES-BEGIN\n#### LNMP-SITES-END\n" | sudo tee -a /etc/hosts > /dev/null
