#!/bin/bash -ex

##
# some code come from fsl_sdcard_partition.sh
##

usage() {
	echo "$(basename $0) /dev/sdx"
	exit 1
}

die() {
	echo $@ >&2
	exit 1
}

# partition size in MB
BOOT_ROM_SIZE=16
# partition size in percent
DATA_PERCENT=40
CACHE_PERCENT=10
RECOVERY_ROM_PERCENT=5

if [[ $(( $SYSTEM_ROM_PERCENT + $DATA_PERCENT + $CACHE_PERCENT + $RECOVERY_ROM_PERCENT )) -gt 98 ]]; then
	die "I need some room for the fat partition"
fi

if [[ $# -ne 1 ]]; then
	usage
fi
node=$1

[[ -b $node ]] || die "$node is not a block device"

! grep ^$node /etc/mtab > /dev/null || die "$node is mounted"

#make sure everything is compiled
[[ -n $ANDROID_PRODUCT_OUT ]] || die "have a lunch !"

UBOOTIMG=$ANDROID_PRODUCT_OUT/u-boot.bin
BOOTIMG=$ANDROID_PRODUCT_OUT/boot.img
RECOVERYIMG=$ANDROID_PRODUCT_OUT/recovery.img
SYSTEMIMG=$ANDROID_PRODUCT_OUT/system.img
DATADIR=$ANDROID_PRODUCT_OUT/data

if [[ ! -f $UBOOTIMG ]] || [[ ! -f $BOOTIMG ]] || [[ ! -f $RECOVERYIMG ]] || [[ ! -f $SYSTEMIMG ]] || \
	[[ ! -d $DATADIR ]]; then
	die "did you make something?"
fi

total_size=$(( `sudo sfdisk -s ${node}` / 1024 ))
# @see imx6/BoardConfigCommon.mk BOARD_SYSTEMIMAGE_PARTITION_SIZE
SYSTEM_ROM_SIZE=$(( `sudo sfdisk -s ${SYSTEMIMG}` / 1024 + 10))
usuable_size=$(( ${total_size} - ${BOOT_ROM_SIZE} - ${SYSTEM_ROM_SIZE} ))
DATA_SIZE=$(( ${usuable_size} * ${DATA_PERCENT} / 100 ))
CACHE_SIZE=$(( ${usuable_size} * ${CACHE_PERCENT} / 100 ))
RECOVERY_ROM_SIZE=$(( ${usuable_size} * ${RECOVERY_ROM_PERCENT} / 100 ))
rom_size=$(( ${BOOT_ROM_SIZE} + ${SYSTEM_ROM_SIZE} + ${DATA_SIZE} + ${CACHE_SIZE} + ${RECOVERY_ROM_SIZE} ))
extend_size=$(( ${SYSTEM_ROM_SIZE} + ${DATA_SIZE} + ${CACHE_SIZE} ))
## FIXME: sfdisk should know how to take all remaining space for this partition
vfat_size=$(( ${total_size} - ${BOOT_ROM_SIZE} - ${extend_size} - ${RECOVERY_ROM_SIZE} ))


# destroy the partition table
sudo dd if=/dev/zero of=${node} bs=1024 count=1

###
# PARTITION LAYOUT
#
# The fat partition must be on part number n with n < 4
# system/vold/Volume.cpp,Volume::mountVol,line 380 for details
#
# From uboot include/configs/mx6q_sabresd_android.h :
#   BOOT     1
#   SYSTEM   5
#   RECOVERY 2
#   CACHE    6
###
sudo sfdisk --force -uM ${node} << EOF
,${BOOT_ROM_SIZE},83
,${RECOVERY_ROM_SIZE},83
,${vfat_size},b
,${extend_size},5
,${SYSTEM_ROM_SIZE},83
,${CACHE_SIZE},83
,${DATA_SIZE},83
EOF


sudo mkfs.vfat ${node}3
sudo mkfs.ext4 ${node}5
sudo mkfs.ext4 ${node}6 -O^extents
sudo mkfs.ext4 ${node}7


sudo dd if=$UBOOTIMG of=${node} bs=1k seek=1 skip=1
sudo dd if=$BOOTIMG of=${node}1
sudo dd if=$RECOVERYIMG of=${node}2
sudo dd if=$SYSTEMIMG of=${node}5

## dd remove label, that's why we do not do this in mkfs
sudo tune2fs -L system ${node}5
sudo tune2fs -L cache ${node}6
sudo tune2fs -L data ${node}7

sudo sync
