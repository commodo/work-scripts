#!/bin/sh
set -e

process_single_defconfig() {
	DEFCONFIG=$1

	if [ -z "$DEFCONFIG" ] ; then
		echo "No defconfig specified"
		exit 1
	fi

	ARCH=$(find . -name $DEFCONFIG | cut -d/ -f3)

	if [ -z "$ARCH" ] ; then
		echo "Could not find ARCH for $DEFCONFIG"
		exit 1
	fi

	defconfig="arch/$ARCH/configs/$DEFCONFIG"

	if [ ! -f "$defconfig" ] ; then
		echo "File does not exist '$defconfig'"
		exit 1 
	fi

	export ARCH

	make $DEFCONFIG
	make savedefconfig
	mv defconfig $defconfig
}


DEFCONFIG=$1

if [ -z "$DEFCONFIG" ] ; then
	echo "No defconfig specified"
	exit 1
fi

while [ -n "$1" ] ; do
	process_single_defconfig "$1"
	shift
done
