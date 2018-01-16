#!/bin/bash
# AIK-Linux/unpackimg: split image and unpack ramdisk
# osm0sis @ xda-developers

cleanup() { $aik/cleanup.sh >/dev/null; }
abort() { cd "$aik"; echo "Error!"; }

case $1 in
  --help) echo "usage: unpackimg.sh [--nosudo] <file>"; exit 1;;
  --nosudo) nosudo=1; shift;;
  --sudo) shift;;
esac;
if [ ! "$nosudo" ]; then
  sudo=sudo; sumsg=" (as root)";
fi;

case $(uname -s) in
  Darwin|Macintosh)
    plat="macos";
    readlink() { perl -MCwd -e 'print Cwd::abs_path shift' "$2"; }
  ;;
  *) plat="linux";;
esac;
arch=$plat/`uname -m`;

aik="${BASH_SOURCE:-$0}";
aik="$(dirname "$(readlink -f "$aik")")";
bin="$aik/bin";
rel=bin;
cur="$(readlink -f "$PWD")";

case $plat in
  macos)
    cpio="env DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/cpio"";
    statarg="-f %Su";
    dd() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/dd" "$@"; }
    file() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/file" "$@"; }
    lzma() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/xz" "$@"; }
    lzop() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/lzop" "$@"; }
    tail() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/tail" "$@"; }
    xz() { DYLD_LIBRARY_PATH="$bin/$arch" "$bin/$arch/xz" "$@"; }
  ;;
  linux)
    cpio=cpio;
    statarg="-c %U";
  ;;
esac;

cd "$aik";
chmod -R 755 "$bin" *.sh;
chmod 644 "$bin/magic" "$bin/androidbootimg.magic" "$bin/BootSignature.jar" "$bin/avb/"* "$bin/chromeos/"*;

test -f "$cur/$1" && img="$cur/$1" || img="$1";
if [ ! "$img" ]; then
  while IFS= read -r line; do
    case $line in
      aboot.img|image-new.img|unlokied-new.img|unsigned-new.img) continue;;
    esac;
    img="$line";
    break;
  done < <(ls *.elf *.img *.sin 2>/dev/null);
fi;
img="$(readlink -f "$img")";
if [ ! -f "$img" ]; then
  echo "No image file supplied.";
  abort;
  exit 1;
fi;

clear;
echo " ";
echo "Android Image Kitchen - UnpackImg Script";
echo "by osm0sis @ xda-developers";
echo " ";

file=$(basename "$img");
echo "Supplied image: $file";
echo " ";

if [ -d split_img -o -d ramdisk ]; then
  if [ -d ramdisk ] && [ "$(stat $statarg ramdisk | head -n 1)" = "root" -o ! "$(find ramdisk 2>&1 | cpio -o >/dev/null 2>&1; echo $?)" -eq "0" ]; then
    rmsumsg=" (as root)";
  fi;
  echo "Removing old work folders and files$rmsumsg...";
  echo " ";
  cleanup;
fi;

echo "Setting up work folders...";
echo " ";
mkdir split_img ramdisk;

imgtest="$(file -m $rel/androidbootimg.magic "$img" | cut -d: -f2-)";
if [ "$(echo $imgtest | awk '{ print $2 }' | cut -d, -f1)" = "signing" ]; then
  echo $imgtest | awk '{ print $1 }' > "split_img/$file-sigtype";
  sigtype=$(cat "split_img/$file-sigtype");
  echo "Signature with \"$sigtype\" type detected, removing...";
  echo " ";
  case $sigtype in
    BLOB)
      cd split_img;
      cp -f "$img" "$file";
      "$bin/$arch/blobunpack" "$file" | tail -n+5 | cut -d" " -f2 | dd bs=1 count=3 > "$file-blobtype" 2>/dev/null;
      mv -f "$file."* "$file";
      cd ..;
    ;;
    CHROMEOS) "$bin/$arch/futility" vbutil_kernel --get-vmlinuz "$img" --vmlinuz-out "split_img/$file";;
    DHTB) dd bs=4096 skip=512 iflag=skip_bytes conv=notrunc if="$img" of="split_img/$file" 2>/dev/null;;
    NOOK)
      dd bs=1048576 count=1 conv=notrunc if="$img" of="split_img/$file-master_boot.key" 2>/dev/null;
      dd bs=1048576 skip=1 conv=notrunc if="$img" of="split_img/$file" 2>/dev/null;
    ;;
    SIN)
      "$bin/$arch/kernel_dump" split_img "$img" >/dev/null;
      mv -f "split_img/$file."* "split_img/$file";
      rm -rf "split_img/$file-sigtype";
    ;;
  esac;
  img="$aik/split_img/$file";
fi;

imgtest="$(file -m $rel/androidbootimg.magic "$img" | cut -d: -f2-)";
if [ "$(echo $imgtest | awk '{ print $2 }' | cut -d, -f1)" = "bootimg" ]; then
  test "$(echo $imgtest | awk '{ print $3 }')" = "PXA" && typesuffix=-PXA;
  echo "$(echo $imgtest | awk '{ print $1 }')$typesuffix" > "split_img/$file-imgtype";
  imgtype=$(cat "split_img/$file-imgtype");
else
  cleanup;
  echo "Unrecognized format.";
  abort;
  exit 1;
fi;
echo "Image type: $imgtype";
echo " ";

case $imgtype in
  AOSP*|ELF|KRNL|U-Boot) ;;
  *)
    cleanup;
    echo "Unsupported format.";
    abort;
    exit 1;
  ;;
esac;

if [ "$(echo $imgtest | awk '{ print $3 }')" = "LOKI" ]; then
  echo $imgtest | awk '{ print $5 }' | cut -d\( -f2 | cut -d\) -f1 > "split_img/$file-lokitype";
  lokitype=$(cat "split_img/$file-lokitype");
  echo "Loki patch with \"$lokitype\" type detected, reverting...";
  echo " ";
  echo "Warning: A dump of your device's aboot.img is required to re-Loki!";
  echo " ";
  "$bin/$arch/loki_tool" unlok "$img" "split_img/$file" >/dev/null;
  img="$file";
fi;

tailtest="$(tail -n50 "$img" 2>/dev/null | file -m $rel/androidbootimg.magic - | cut -d: -f2-)";
tailtype="$(echo $tailtest | awk '{ print $1 }')";
case $tailtype in
  AVB)
    echo "Signature with \"$tailtype\" type detected.";
    echo " ";
    echo $tailtype > "split_img/$file-sigtype";
    echo $tailtest | awk '{ print $5 }' > "split_img/$file-avbtype";
  ;;
  Bump|SEAndroid)
    echo "Footer with \"$tailtype\" type detected.";
    echo " ";
    echo $tailtype > "split_img/$file-tailtype";
  ;;
esac;

echo 'Splitting image to "split_img/"...';
cd split_img;
case $imgtype in
  AOSP) "$bin/$arch/unpackbootimg" -i "$img";;
  AOSP-PXA) "$bin/$arch/pxa-unpackbootimg" -i "$img";;
  ELF) "$bin/$arch/unpackelf" -i "$img";;
  KRNL) dd bs=4096 skip=8 iflag=skip_bytes conv=notrunc if="$img" of="$file-ramdisk.cpio.gz" 2>&1 | tail -n+3 | cut -d" " -f1-2;;
  U-Boot)
    "$bin/$arch/dumpimage" -l "$img";
    "$bin/$arch/dumpimage" -l "$img" > "$file-header";
    grep "Name:" "$file-header" | cut -c15- > "$file-name";
    grep "Type:" "$file-header" | cut -c15- | cut -d" " -f1 > "$file-arch";
    grep "Type:" "$file-header" | cut -c15- | cut -d" " -f2 > "$file-os";
    grep "Type:" "$file-header" | cut -c15- | cut -d" " -f3 | cut -d- -f1 > "$file-type";
    grep "Type:" "$file-header" | cut -d\( -f2 | cut -d\) -f1 | cut -d" " -f1 | cut -d- -f1 > "$file-comp";
    grep "Address:" "$file-header" | cut -c15- > "$file-addr";
    grep "Point:" "$file-header" | cut -c15- > "$file-ep";
    rm -rf "$file-header";
    "$bin/$arch/dumpimage" -i "$img" -p 0 "$file-zImage";
    if [ ! $? -eq "0" ]; then
      cleanup;
      abort;
      exit 1;
    fi;
    if [ "$(cat "$file-type")" = "Multi" ]; then
      "$bin/$arch/dumpimage" -i "$img" -p 1 "$file-ramdisk.cpio.gz";
    else
      touch "$file-ramdisk.cpio.gz";
    fi;
  ;;
esac;
if [ ! $? -eq "0" ]; then
  cleanup;
  abort;
  exit 1;
fi;

if [ "$imgtype" = "AOSP" ] && [ "$(cat "$file-hash")" = "unknown" ]; then
  echo " ";
  echo 'Warning: "unknown" hash type detected; assuming "sha1" type!';
  echo "sha1" > "$file-hash";
fi;

if [ "$(file -m ../$rel/androidbootimg.magic *-zImage | cut -d: -f2 | awk '{ print $1 }')" = "MTK" ]; then
  mtk=1;
  echo " ";
  echo "MTK header found in zImage, removing...";
  dd bs=512 skip=1 conv=notrunc if="$file-zImage" of=tempzimg 2>/dev/null;
  mv -f tempzimg "$file-zImage";
fi;
mtktest="$(file -m ../$rel/androidbootimg.magic *-ramdisk*.gz | cut -d: -f2-)";
mtktype=$(echo $mtktest | awk '{ print $3 }');
if [ "$(echo $mtktest | awk '{ print $1 }')" = "MTK" ]; then
  if [ ! "$mtk" ]; then
    echo " ";
    echo "Warning: No MTK header found in zImage!";
    mtk=1;
  fi;
  echo "MTK header found in \"$mtktype\" type ramdisk, removing...";
  dd bs=512 skip=1 conv=notrunc if="$(ls *-ramdisk*.gz)" of=temprd 2>/dev/null;
  mv -f temprd "$(ls *-ramdisk*.gz)";
else
  if [ "$mtk" ]; then
    if [ ! "$mtktype" ]; then
      echo 'Warning: No MTK header found in ramdisk, assuming "rootfs" type!';
      mtktype="rootfs";
    fi;
  fi;
fi;
test "$mtk" && echo $mtktype > "$file-mtktype";

if [ -f *-dtb ]; then
  dtbtest="$(file -m ../$rel/androidbootimg.magic *-dtb | cut -d: -f2 | awk '{ print $1 }')";
  if [ "$imgtype" = "ELF" ]; then
    case $dtbtest in
      QCDT|ELF) ;;
      *) echo " ";
         echo "Non-QC DTB found, packing zImage and appending...";
         gzip --no-name -9 "$file-zImage";
         mv -f "$file-zImage.gz" "$file-zImage";
         cat "$file-dtb" >> "$file-zImage";
         rm -f "$file-dtb";;
    esac;
  fi;
fi;

file -m ../$rel/magic *-ramdisk*.gz | cut -d: -f2 | awk '{ print $1 }' > "$file-ramdiskcomp";
ramdiskcomp=`cat *-ramdiskcomp`;
unpackcmd="$ramdiskcomp -dc";
compext=$ramdiskcomp;
case $ramdiskcomp in
  gzip) unpackcmd="gzip -dcq"; compext=gz;;
  lzop) compext=lzo;;
  xz) ;;
  lzma) ;;
  bzip2) compext=bz2;;
  lz4) unpackcmd="$bin/$arch/lz4 -dcq";;
  empty) compext=empty;;
  *) compext="";;
esac;
if [ "$compext" ]; then
  compext=.$compext;
fi;
mv -f "$(ls *-ramdisk*.gz)" "$file-ramdisk.cpio$compext" 2>/dev/null;
cd ..;
if [ "$ramdiskcomp" = "data" ]; then
  echo "Unrecognized format.";
  abort;
  exit 1;
fi;

echo " ";
if [ "$ramdiskcomp" = "empty" ]; then
  echo "Warning: No ramdisk found to be unpacked!";
else
  echo "Unpacking ramdisk$sumsg to \"ramdisk/\"...";
  echo " ";
  $sudo chown 0:0 ramdisk 2>/dev/null;
  cd ramdisk;
  echo "Compression used: $ramdiskcomp";
  if [ ! "$compext" ]; then
    echo "Unsupported format.";
    abort;
    exit 1;
  fi;
  $unpackcmd "../split_img/$file-ramdisk.cpio$compext" | $sudo $cpio -i -d --no-absolute-filenames;
  if [ ! $? -eq "0" ]; then
    test "$nosudo" && echo "Unpacking failed, try without --nosudo.";
    abort;
    exit 1;
  fi;
  cd ..;
fi;

echo " ";
echo "Done!";
exit 0;

