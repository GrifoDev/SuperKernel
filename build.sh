#!/bin/bash
# kernel build script by Tkkg1994 v0.4 (optimized from apq8084 kernel source)
# Modified by djb77 / XDA Developers

# ---------
# VARIABLES
# ---------
BUILD_SCRIPT=2.34
VERSION_NUMBER=2.6.0
ARCH=arm64
BUILD_CROSS_COMPILE=~/android/toolchains/aarch64-cortex_a53-linux-gnueabi/bin/aarch64-cortex_a53-linux-gnueabi-
BUILD_JOB_NUMBER=`grep processor /proc/cpuinfo|wc -l`
RDIR=$(pwd)
OUTDIR=$RDIR/arch/$ARCH/boot
DTSDIR=$RDIR/arch/$ARCH/boot/dts
DTBDIR=$OUTDIR/dtb
DTCTOOL=$RDIR/scripts/dtc/dtc
INCDIR=$RDIR/include
PAGE_SIZE=2048
DTB_PADDING=0
KERNELNAME=SuperKernel
KERNELCONFIG=SuperKernel

# ---------
# FUNCTIONS
# ---------
FUNC_CLEAN()
{
echo ""
echo "Deleting old work files"
echo ""
make -s clean
make -s ARCH=arm64 distclean
rm -f $RDIR/build/*.img
rm -f $RDIR/build/*.log
rm -rf $RDIR/arch/arm64/boot/dtb
rm -f $RDIR/arch/$ARCH/boot/dts/*.dtb
rm -f $RDIR/arch/$ARCH/boot/boot.img-dtb
rm -f $RDIR/arch/$ARCH/boot/boot.img-zImage
rm -f $RDIR/ramdisk/SM-G930F/image-new.img
rm -f $RDIR/ramdisk/SM-G930F/ramdisk-new.cpio.gz
rm -f $RDIR/ramdisk/SM-G930F/image-new.img
rm -f $RDIR/ramdisk/SM-G935F/ramdisk-new.cpio.gz
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/acct/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/cache/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/data/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/dev/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/lib/modules/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/mnt/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/proc/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/storage/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/sys/Placeholder
echo "" > $RDIR/ramdisk/SM-G930F/ramdisk/system/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/acct/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/cache/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/data/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/dev/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/lib/modules/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/mnt/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/proc/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/storage/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/sys/Placeholder
echo "" > $RDIR/ramdisk/SM-G935F/ramdisk/system/Placeholder
}

FUNC_DELETE_PLACEHOLDERS()
{
find . -name \Placeholder -type f -delete
}

FUNC_BUILD_ZIMAGE()
{
echo "Loading configuration"
echo ""
make -s -j$BUILD_JOB_NUMBER ARCH=$ARCH \
	CROSS_COMPILE=$BUILD_CROSS_COMPILE \
	$KERNEL_DEFCONFIG || exit -1
echo ""
echo "Compiling zImage"
echo ""
make -s -j$BUILD_JOB_NUMBER ARCH=$ARCH \
	CROSS_COMPILE=$BUILD_CROSS_COMPILE || exit -1
echo ""
}

FUNC_BUILD_DTB()
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
echo ""
echo "Processing dts files"
echo ""
for dts in $DTSFILES; do
	echo "=> Processing: ${dts}.dts"
	${CROSS_COMPILE}cpp -nostdinc -undef -x assembler-with-cpp -I "$INCDIR" "$DTSDIR/${dts}.dts" > "${dts}.dts"
	echo "=> Generating: ${dts}.dtb"
	$DTCTOOL -p $DTB_PADDING -i "$DTSDIR" -O dtb -o "${dts}.dtb" "${dts}.dts"
done
echo ""
echo "Generating dtb.img"
echo ""
$RDIR/scripts/dtbTool/dtbTool -o "$OUTDIR/dtb.img" -d "$DTBDIR/" -s $PAGE_SIZE
}

FUNC_BUILD_RAMDISK()
{

if [ ! -f "$RDIR/ramdisk/SM-G930F/ramdisk/config" ]; then
	mkdir $RDIR/ramdisk/SM-G930F/ramdisk/config
	chmod 500 $RDIR/ramdisk/SM-G930F/ramdisk/config
fi
if [ ! -f "$RDIR/ramdisk/SM-G935F/ramdisk/config" ]; then
	mkdir $RDIR/ramdisk/SM-G935F/ramdisk/config
	chmod 500 $RDIR/ramdisk/SM-G935F/ramdisk/config
fi

mv $RDIR/arch/$ARCH/boot/Image $RDIR/arch/$ARCH/boot/boot.img-zImage
mv $RDIR/arch/$ARCH/boot/dtb.img $RDIR/arch/$ARCH/boot/boot.img-dtb
case $MODEL in
herolte)
	rm -f $RDIR/ramdisk/SM-G930F/split_img/boot.img-zImage
	rm -f $RDIR/ramdisk/SM-G930F/split_img/boot.img-dtb
	mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-G930F/split_img/boot.img-zImage
	mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/ramdisk/SM-G930F/split_img/boot.img-dtb
	cd $RDIR/ramdisk/SM-G930F
	./repackimg.sh
	echo SEANDROIDENFORCE >> image-new.img
	;;
hero2lte)
	rm -f $RDIR/ramdisk/SM-G935F/split_img/boot.img-zImage
	rm -f $RDIR/ramdisk/SM-G935F/split_img/boot.img-dtb
	mv -f $RDIR/arch/$ARCH/boot/boot.img-zImage $RDIR/ramdisk/SM-G935F/split_img/boot.img-zImage
	mv -f $RDIR/arch/$ARCH/boot/boot.img-dtb $RDIR/ramdisk/SM-G935F/split_img/boot.img-dtb
	cd $RDIR/ramdisk/SM-G935F
	./repackimg.sh
	echo SEANDROIDENFORCE >> image-new.img
	;;
*)
	echo "Unknown device: $MODEL"
	exit 1
	;;
esac
}

FUNC_BUILD_BOOTIMG()
{
	FUNC_CLEAN
	FUNC_DELETE_PLACEHOLDERS
	(
	FUNC_BUILD_ZIMAGE
	FUNC_BUILD_DTB
	FUNC_BUILD_RAMDISK
	) 2>&1	 | tee -a $RDIR/build/build.log
}

FUNC_BUILD_ZIP()
{
echo ""
echo "Building Zip File"
cd $ZIP_FILE_DIR
zip -gq $ZIP_NAME -r META-INF/ -x "*~"
zip -gq $ZIP_NAME -r files/ -x "*~" 
zip -gq $ZIP_NAME -r mcRegistry/ -x "*~" 
zip -gq $ZIP_NAME -r vendor/ -x "*~" 
[ -f "$RDIR/build/herolte-eur.img" ] && zip -gq $ZIP_NAME herolte-eur.img -x "*~"
[ -f "$RDIR/build/hero2lte-eur.img" ] && zip -gq $ZIP_NAME hero2lte-eur.img -x "*~"
chmod a+r $ZIP_NAME
cd $RDIR
}

OPTION_1()
{
rm -f $RDIR/build/build.log
MODEL=herolte
KERNEL_DEFCONFIG=$KERNELCONFIG-herolte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G930F/image-new.img $RDIR/build/herolte-eur.img
mv -f $RDIR/build/build.log $RDIR/build/build-g930f.log
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your herolte-eur.img in the build folder"
echo "You can now find your build-g930f.log file in the build folder"
echo ""
exit
}

OPTION_2()
{
rm -f $RDIR/build/build.log
MODEL=hero2lte
KERNEL_DEFCONFIG=$KERNELCONFIG-hero2lte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G935F/image-new.img $RDIR/build/hero2lte-eur.img
mv -f $RDIR/build/build.log $RDIR/build/build-g935f.log
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your hero2lte-eur.img in the build folder"
echo "You can now find your build-g935f.log file in the build folder"
echo ""
exit
}

OPTION_3()
{
rm -f $RDIR/build/build.log
MODEL=herolte
KERNEL_DEFCONFIG=$KERNELCONFIG-herolte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G930F/image-new.img $RDIR/build/herolte-eur.img-save
mv -f $RDIR/build/build.log $RDIR/build/build-g930f.log-save
MODEL=hero2lte
KERNEL_DEFCONFIG=$KERNELCONFIG-hero2lte_defconfig
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/build/g930f.img-save $RDIR/build/g930f.img
mv -f $RDIR/ramdisk/SM-G935F/image-new.img $RDIR/build/hero2lte-eur.img
mv -f $RDIR/build/build-g930f.log-save $RDIR/build/build-g930f.log
mv -f $RDIR/build/build.log $RDIR/build/build-g935f.log
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your herolte-eur.img in the build folder"
echo "You can now find your hero2lte-eur.img in the build folder"
echo "You can now find your build-g930f.log file in the build folder"
echo "You can now find your build-g935f.log file in the build folder"
echo ""
exit
}

OPTION_4()
{
rm -f $RDIR/build/build.log
MODEL=herolte
KERNEL_DEFCONFIG=$KERNELCONFIG-herolte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G930F/image-new.img $RDIR/build/herolte-eur.img
mv -f $RDIR/build/build.log $RDIR/build/build-g930f.log
ZIP_DATE=`date +%Y%m%d`
ZIP_FILE_DIR=$RDIR/build
ZIP_NAME=SuperKernel_SM-G930F_v$VERSION_NUMBER.zip
ZIP_FILE_TARGET=$ZIP_FILE_DIR/$ZIP_NAME
FUNC_BUILD_ZIP
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your .zip file in the build folder"
echo "You can now find your build-g930f.log file in the build folder"
echo ""
exit
}

OPTION_5()
{
rm -f $RDIR/build/build.log
MODEL=hero2lte
KERNEL_DEFCONFIG=$KERNELCONFIG-hero2lte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G935F/image-new.img $RDIR/build/hero2lte-eur.img
mv -f $RDIR/build/build.log $RDIR/build/build-g935f.log
ZIP_DATE=`date +%Y%m%d`
ZIP_FILE_DIR=$RDIR/build
ZIP_NAME=SuperKernel_SM-G935F_v$VERSION_NUMBER.zip
ZIP_FILE_TARGET=$ZIP_FILE_DIR/$ZIP_NAME
FUNC_BUILD_ZIP
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your .zip file in the build folder"
echo "You can now find your build-g935f.log file in the build folder"
echo ""
exit
}

OPTION_6()
{
rm -f $RDIR/build/build.log
MODEL=herolte
KERNEL_DEFCONFIG=$KERNELCONFIG-herolte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G930F/image-new.img $RDIR/build/herolte-eur.img
mv -f $RDIR/build/build.log $RDIR/build/build-g930f.log-save
ZIP_FILE_DIR=$RDIR/build
ZIP_NAME=SuperKernel_SM-G930F_v$VERSION_NUMBER.zip
ZIP_NAME1=$ZIP_NAME
ZIP_FILE_TARGET=$ZIP_FILE_DIR/$ZIP_NAME
FUNC_BUILD_ZIP
mv -f $ZIP_NAME $ZIP_NAME.safe
MODEL=hero2lte
KERNEL_DEFCONFIG=$KERNELCONFIG-hero2lte_defconfig
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G935F/image-new.img $RDIR/build/hero2lte-eur.img
mv -f $RDIR/build/build-g930f.log-save $RDIR/build/build-g930f.log
mv -f $RDIR/build/build.log $RDIR/build/build-g935f.log
ZIP_FILE_DIR=$RDIR/build
ZIP_NAME=SuperKernel_SM-G935F_v$VERSION_NUMBER.zip
ZIP_FILE_TARGET=$ZIP_FILE_DIR/$ZIP_NAME
FUNC_BUILD_ZIP
mv -f $ZIP_NAME1.safe $ZIP_NAME1
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your .zip files in the build folder"
echo "You can now find your build-g930f.log file in the build folder"
echo "You can now find your build-g935f.log file in the build folder"
echo ""
exit
}

OPTION_7()
{
rm -f $RDIR/build/build.log
MODEL=herolte
KERNEL_DEFCONFIG=$KERNELCONFIG-herolte_defconfig
START_TIME=`date +%s`
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/ramdisk/SM-G930F/image-new.img $RDIR/build/herolte-eur.img-save
mv -f $RDIR/build/build.log $RDIR/build/build-g930f.log-save
MODEL=hero2lte
KERNEL_DEFCONFIG=$KERNELCONFIG-hero2lte_defconfig
	(
	FUNC_BUILD_BOOTIMG
	) 2>&1	 | tee -a $RDIR/build/build.log
mv -f $RDIR/build/herolte-eur.img-save $RDIR/build/herolte-eur.img
mv -f $RDIR/ramdisk/SM-G935F/image-new.img $RDIR/build/hero2lte-eur.img.img
mv -f $RDIR/build/build-g930f.log-save $RDIR/build/build-g930f.log
mv -f $RDIR/build/build.log $RDIR/build/build-g935f.log
ZIP_DATE=`date +%Y%m%d`
ZIP_FILE_DIR=$RDIR/build
ZIP_NAME=SuperKernel_SM-G93XX_v$VERSION_NUMBER.zip
ZIP_FILE_TARGET=$ZIP_FILE_DIR/$ZIP_NAME
FUNC_BUILD_ZIP
END_TIME=`date +%s`
let "ELAPSED_TIME=$END_TIME-$START_TIME"
echo ""
echo "Total compiling time is $ELAPSED_TIME seconds"
echo ""
echo "You can now find your .zip file in the build folder"
echo "You can now find your build-g930f.log file in the build folder"
echo "You can now find your build-g935f.log file in the build folder"
echo ""
exit
}

OPTION_0()
{
FUNC_CLEAN
exit
}

# ----------------------------------
# CHECK COMMAND LINE FOR ANY ENTRIES
# ----------------------------------
if [ $1 == 0 ]; then
	OPTION_0
fi
if [ $1 == 1 ]; then
	OPTION_1
fi
if [ $1 == 2 ]; then
	OPTION_2
fi
if [ $1 == 3 ]; then
	OPTION_3
fi
if [ $1 == 4 ]; then
	OPTION_4
fi
if [ $1 == 5 ]; then
	OPTION_5
fi
if [ $1 == 6 ]; then
	OPTION_6
fi
if [ $1 == 7 ]; then
	OPTION_7
fi

# -------------
# PROGRAM START
# -------------
rm -rf ./build/build.log
clear
echo "SuperKernel Build Script v$BUILD_SCRIPT -- Kernel Version: v$VERSION_NUMBER"
echo ""
echo " 0) Clean Workspace"
echo ""
echo " 1) Build SuperKernel boot.img for S7"
echo " 2) Build SuperKernel boot.img for S7 Edge"
echo " 3) Build SuperKernel boot.img for S7 + S7 Edge"
echo " 4) Build SuperKernel boot.img and .zip for S7"
echo " 5) Build SuperKernel boot.img and .zip for S7 Edge"
echo " 6) Build SuperKernel boot.img and .zip for S7 + S7 Edge (Seperate)"
echo " 7) Build SuperKernel boot.img and .zip for S7 + S7 Edge (All-In-One)"
echo ""
echo " 9) Exit"
echo ""
read -p "Please select an option " prompt
echo ""
if [ $prompt == "0" ]; then
	OPTION_0
elif [ $prompt == "1" ]; then
	OPTION_1
elif [ $prompt == "2" ]; then
	OPTION_2
elif [ $prompt == "3" ]; then
	OPTION_3
elif [ $prompt == "4" ]; then
	OPTION_4
elif [ $prompt == "5" ]; then
	OPTION_5
elif [ $prompt == "6" ]; then
	OPTION_6
elif [ $prompt == "7" ]; then
	OPTION_7
elif [ $prompt == "9" ]; then
	exit
fi

