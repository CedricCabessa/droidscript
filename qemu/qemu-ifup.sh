#!/bin/bash -x

# Adapted from http://en.wikibooks.org/wiki/QEMU/Networking
# Qemu will need cap_net_admin:
#    setcap cap_net_admin+ep emulator-arm

#
# script to bring up the tun device in QEMU in bridged mode
# first parameter is name of tap device (e.g. tap0)
#
# some constants specific to the local host - change to suit your host
#

# header:2 lo:1 ethn:1 tap:1 = 5
if [[ $(wc -l /proc/net/dev | awk '{print $1}') -gt 5 ]]; then
	echo "too many interfaces !" >&2
	exit 1
fi
DEV=$(sed -n 's/[[:space:]]*\(.*\):.*/\1/p' /proc/net/dev | grep -v ^lo$ | grep -v ^$1$)

ipmask=$(ip addr show $DEV | awk '/inet\ /  {print $2}')
IPMASK=$(ip addr show $DEV | sed -n 's/.*inet\ \([0-9\./]*\).*/\1/p')
GATEWAY=$(route -n | awk '/^0.0.0.0/ {print $2}')
BROADCAST=$(ip addr show $DEV |  sed -n 's/.*inet\ .*brd\ \([0-9\.]*\).*/\1/p')


#
# First take eth0 down, then bring it up with IP 0.0.0.0
#
sudo ifconfig $DEV down
sudo ifconfig $DEV 0.0.0.0 promisc up
#
# Bring up the tap device (name specified as first argument, by QEMU)
#

sudo tunctl -t $1 -u $UID
sudo ifconfig $1 0.0.0.0 promisc up
#
# create the bridge between eth0 and the tap device
#
sudo brctl addbr br0
sudo brctl addif br0 $DEV
sudo brctl addif br0 $1
#
# only a single bridge so loops are not possible, turn off spanning tree protocol
#
sudo brctl stp br0 off
#
# Bring up the bridge with IP and add the default route
#
sudo ifconfig br0 $IPMASK broadcast $BROADCAST
sudo route add default gw $GATEWAY
