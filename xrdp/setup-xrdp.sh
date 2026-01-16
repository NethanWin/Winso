#!/bin/bash

sudo mkdir -p /etc/polkit-1/localauthority/90-mandatory.d
sudo mv 99-xrdp.pkla /etc/polkit-1/localauthority/90-mandatory.d/

sudo mv startwm.sh /etc/xrdp/startwm.sh
