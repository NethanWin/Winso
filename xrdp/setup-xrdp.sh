#!/bin/bash

sudo mkdir -p /etc/polkit-1/localauthority/90-mandatory.d
sudo cp 99-xrdp.pkla /etc/polkit-1/localauthority/90-mandatory.d/

sudo cp startwm.sh /etc/xrdp/startwm.sh

cp .xsession $HOME/.xsession

sudo systemctl restart xrdp xrdp-sesman
