#!/bin/bash
# kernel build script by Tkkg1994 v0.5 (optimized from apq8084 kernel source)

export MODEL=herolte
export ARCH=arm64
export BUILD_CROSS_COMPILE=../Toolchain/aarch64-cortex_a53-linux-gnueabi-6.4.0/bin/aarch64-cortex_a53-linux-gnueabi-
export BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`

RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include

PAGE_SIZE=2048
DTB_PADDING=0

if [ $MODEL = herolte ]; then
	KERNEL_DEFCONFIG=exynos8890-herolte_defconfig
else if [ $MODEL = hero2lte ]; then
	KERNEL_DEFCONFIG=exynos8890-hero2lte_defconfig
else
	echo "Unknown device: $MODEL"
	exit 1
fi
fi

FUNC_CLEAN_DTB()
{
	if ! [ -d $RDIR/arch/$ARCH/boot/dts ] ; then
		echo "no directory : "$RDIR/arch/$ARCH/boot/dts""
	else
		echo "rm files in : "$RDIR/arch/$ARCH/boot/dts/*.dtb""
		rm $RDIR/arch/$ARCH/boot/dts/*.dtb
		rm $RDIR/arch/$ARCH/boot/dtb/*.dtb
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
				exynos8890-herolte_eur_open_09 exynos8890-herolte_eur_open_10"
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

FUNC_BUILD_KERNEL()
{
	echo ""
        echo "=============================================="
        echo "START : FUNC_BUILD_KERNEL"
        echo "=============================================="
        echo ""
        echo "build common config="$KERNEL_DEFCONFIG ""
        echo "build variant config="$MODEL ""

	FUNC_CLEAN_DTB

	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE \
			$KERNEL_DEFCONFIG || exit -1

	make -j$BUILD_JOB_NUMBER ARCH=$ARCH \
			CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1

	FUNC_BUILD_DTIMAGE_TARGET
	
	echo ""
	echo "================================="
	echo "END   : FUNC_BUILD_KERNEL"
	echo "================================="
	echo ""
}

FUNC_BUILD_RAMDISK()
{
	mv $RDIR/arch/$ARCH/boot/Image $RDIR/arch/$ARCH/boot/boot.img-zImage
	mv $RDIR/arch/$ARCH/boot/dtb.img $RDIR/arch/$ARCH/boot/boot.img-dtb

	case $MODEL in
	herolte)
		rm -f $RDIR/ramdisk/SM-G930F/split_img/boot.img-zImage
		rm -f $RDIR/ramdisk/SM-G930F/split_img/boot.img-dtb
		mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-G930F/split_img/boot.img-zImage
		mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/ramdisk/SM-G930F/split_img/boot.img-dtb
		cd $RDIR/ramdisk/SM-G930F
		./repackimg.sh --nosudo
		echo SEANDROIDENFORCE >> image-new.img
		;;
	hero2lte)
		rm -f $RDIR/ramdisk/SM-G935F/split_img/boot.img-zImage
		rm -f $RDIR/ramdisk/SM-G935F/split_img/boot.img-dtb
		mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-G935F/split_img/boot.img-zImage
		mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/ramdisk/SM-G935F/split_img/boot.img-dtb
		cd $RDIR/ramdisk/SM-G935F
		./repackimg.sh --nosudo
		echo SEANDROIDENFORCE >> image-new.img
		;;
	*)
		echo "Unknown device: $MODEL"
		exit 1
		;;
	esac
}


# MAIN FUNCTION
rm -rf ./build.log
(
	START_TIME=`date +%s`

	FUNC_BUILD_KERNEL
	FUNC_BUILD_RAMDISK

	END_TIME=`date +%s`
	
	let "ELAPSED_TIME=$END_TIME-$START_TIME"
	echo "Total compile time was $ELAPSED_TIME seconds"

) 2>&1	 | tee -a ./build.log

