#!/bin/bash
#
# Copyright (c) 2021 bowb 
# MIT Licensed, see LICENSE for more information.
#

set -ex

apt update
apt install qemu qemu-utils qemu-kvm virt-manager -y
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
wget https://dl.google.com/developers/android/rvc/images/gsi/aosp_arm64-exp-RP1A.200720.009-6720564-019b517d.zip -O android.zip
unzip -o android.zip

fallocate -l 3G root.img
mkfs -t ext4 root.img

ANDROIDROOTFS="/tmp/androidrootfs"
ROOTFS="/tmp/rootfs"

mkdir -p $ANDROIDROOTFS
mkdir -p $ROOTFS

mount -t ext4 -o loop,ro system.img $ANDROIDROOTFS
mount -t ext4 -o loop,rw,sync root.img $ROOTFS

cp $ANDROIDROOTFS/system/* -ar $ROOTFS

mkdir -p $ROOTFS/system/bin
ln -s ../lib64 $ROOTFS/system/lib64

cp -rpa $ANDROIDROOTFS/system/system_ext/apex/com.android.runtime/bin/* $ROOTFS/system/bin/

cp -ra $ANDROIDROOTFS/system/system_ext/apex/* $ROOTFS/apex

mkdir $ROOTFS/proc
mkdir $ROOTFS/dev
mount -t proc none $ROOTFS/proc
mount -o bind /dev $ROOTFS/dev

cp $(which qemu-aarch64-static) $ROOTFS/bin 

chroot $ROOTFS /bin/ls
docker run --rm dockcross/android-arm64:latest > dockcross-android-arm64-latest
chmod +x dockcross-android-arm64-latest
./dockcross-android-arm64-latest bash -c '$CXX -o test test.cpp -static-libstdc++' 

cp test $ROOTFS
chroot $ROOTFS /test

umount $ROOTFS/proc
umount $ROOTFS/dev

mkdir -p docker/rootfs
cp -ra $ROOTFS/* docker/rootfs/

umount $ROOTFS
umount $ANDROIDROOTFS

docker build --tag android:aarch64 docker
docker run --rm android:aarch64 /test

rm -rf docker/rootfs
rm root.img 
