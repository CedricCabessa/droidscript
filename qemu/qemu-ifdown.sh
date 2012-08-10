#!/bin/bash -x

sudo ifconfig br0 down
sudo tunctl -d $1
sudo brctl delbr br0
sudo service network-manager restart

