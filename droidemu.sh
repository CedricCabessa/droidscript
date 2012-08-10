#!/bin/bash

usage() {
	echo "$(basename $0) [--prebuilt] [--qemunet]" 2>&1
	exit 1
}

die() {
	echo $@ 2>&1
	exit 1
}

PREBUILT=0
QEMUNET=0

while [[ $# -ge 1 ]]; do
	case $1 in
		"--prebuilt")
			PREBUILT=1
			;;
		"--qemunet")
			QEMUNET=1
			;;
		*)
			usage
			;;
	esac
	shift
done


if [[ -z $ANDROID_PRODUCT_OUT ]]; then
	die "You have to launch this command in a 'lunch' shell"
fi

EMU_OPT="-skin WXGA720 -partition-size 256"
EMULATOR="$ANDROID_HOST_OUT/bin/emulator-arm"

if [[ $PREBUILT -eq 0 ]]; then
	if [[ ! -f $ANDROID_PRODUCT_OUT/kernel ]]; then
		die "kernel is not compiled"
	fi
	EMU_OPT="$EMU_OPT -kernel $ANDROID_PRODUCT_OUT/kernel"
fi

if [[ $QEMUNET -eq 0 ]]; then
	if ! getcap $EMULATOR | grep cap_net_admin+ep >/dev/null 2>&1 ; then
		sudo setcap cap_net_admin+ep $EMULATOR
	fi

	mac=$(ip addr | grep ether | awk '{print $2}' | sed 's%\([0-9][0-9]\):\(.*\)%42:\2%g')

	QEMU_SCRIPT_DIR="$(dirname $0)/qemu"
	EMU_OPT="$EMU_OPT -qemu -net nic,macaddr=$mac -net tap,ifname=tap0,script=$QEMU_SCRIPT_DIR/qemu-ifup.sh,downscript=$QEMU_SCRIPT_DIR/qemu-ifdown.sh"
fi

echo $EMULATOR $EMU_OPT
$EMULATOR $EMU_OPT
