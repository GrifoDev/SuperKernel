#!/bin/bash

export MODEL=herolte
export ARCH=arm64
export CROSS_COMPILE=/Kernel_Folder/aarch64-linux-gnu-5.3/bin/aarch64-

RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include

PAGE_SIZE=2048
DTB_PADDING=0

FUNC_CLEAN_DTB()
{
	if ! [ -d $RDIR/arch/$ARCH/boot/dts ] ; then
		echo "no directory : "$RDIR/arch/$ARCH/boot/dts""
	else
		echo "rm files in : "$RDIR/arch/$ARCH/boot/dts/*.dtb""
		rm $RDIR/arch/$ARCH/boot/dts/*.dtb
		rm $RDIR/arch/$ARCH/boot/boot.img-dtb
		rm $RDIR/arch/$ARCH/boot/boot.img-zImage
	fi
}

FUNC_BUILD_DTIMAGE_TARGET()
{
[ -f "$DTCTOOL" ] || {
	echo "You need to run ./build.sh first!"
	exit 1
}

case $MODEL in
herolte)
	DTSFILES="exynos8890-herolte_eur_open_00 exynos8890-herolte_eur_open_01
			exynos8890-herolte_eur_open_02 exynos8890-herolte_eur_open_03
			exynos8890-herolte_eur_open_04 exynos8890-herolte_eur_open_08
			exynos8890-herolte_eur_open_09"
	;;
hero2lte)
	DTSFILES="exynos8890-hero2lte_eur_open_00 exynos8890-hero2lte_eur_open_01
			exynos8890-hero2lte_eur_open_03 exynos8890-hero2lte_eur_open_04
			exynos8890-hero2lte_eur_open_08"
	;;
*)
	echo "Unknown device: $MODEL"
	exit 1
	;;
esac

mkdir -p $OUTDIR $DTBDIR

cd $DTBDIR || {
	echo "Unable to cd to $DTBDIR!"
	exit 1
}

rm -f ./*

echo "Processing dts files..."

for dts in $DTSFILES; do
	echo "=> Processing: ${dts}.dts"
	${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
	echo "=> Generating: ${dts}.dtb"
	$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
done

echo "Generating dtb.img..."
$RDIR/scripts/dtbTool/dtbTool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE

echo "Done."
}

FUNC_CLEAN_DTB

case $MODEL in
herolte)
	cp -f $RDIR/arch/$ARCH/configs/SuperKernel-herolte_defconfig $RDIR
	mv -f $RDIR/SuperKernel-herolte_defconfig $RDIR/.config
	;;
hero2lte)
	cp -f $RDIR/arch/$ARCH/configs/SuperKernel-hero2lte_defconfig $RDIR
	mv -f $RDIR/SuperKernel-hero2lte_defconfig $RDIR/.config
	;;
*)
	echo "Unknown device: $MODEL"
	exit 1
	;;
esac

make -j3

FUNC_BUILD_DTIMAGE_TARGET

mv $RDIR/arch/$ARCH/boot/Image $RDIR/arch/$ARCH/boot/boot.img-zImage
mv $RDIR/arch/$ARCH/boot/dtb.img $RDIR/arch/$ARCH/boot/boot.img-dtb

case $MODEL in
herolte)
	rm -f $RDIR/ramdisk/SM-G930F/split_img/boot.img-zImage
	rm -f $RDIR/ramdisk/SM-G930F/split_img/boot.img-dtb
	mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-G930F/split_img/boot.img-zImage
	mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/ramdisk/SM-G930F/split_img/boot.img-dtb
	cd $RDIR/ramdisk/SM-G930F
	'/root/SuperKernel/ramdisk/SM-G930F/repackimg.sh'
	echo SEANDROIDENFORCE >> image-new.img
	;;
hero2lte)
	rm -f $RDIR/ramdisk/SM-G935F/split_img/boot.img-zImage
	rm -f $RDIR/ramdisk/SM-G935F/split_img/boot.img-dtb
	mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-G935F/split_img/boot.img-zImage
	mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/ramdisk/SM-G935F/split_img/boot.img-dtb
	cd $RDIR/ramdisk/SM-G935F
	'/root/SuperKernel/ramdisk/SM-G935F/repackimg.sh'
	echo SEANDROIDENFORCE >> image-new.img
	;;
*)
	echo "Unknown device: $MODEL"
	exit 1
	;;
esac

