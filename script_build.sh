#!/bin/bash

# curl https://raw.githubusercontent.com/vjspranav/RomBuildScript/ryzen7/script_build.sh>script_build.sh
# Make necessary changes before executing script

# Export some variables
# make_clean (yes/no/installclean/deviceclean)
user=kkshedge
lunch=ssos
device_codename=RMX1851
build_type=userdebug
tg_username=@Kkshedge
OUT_PATH="out/target/product/$device_codename"
use_ccache=yes
make_clean=no
stopped=0
finish=0

function finish {
  stopped=1
  rm -rf /tmp/manlocktest.lock;
read -r -d '' msg <<EOT
<b>Build Stopped</b>
<b>Device:-</b> ${device_codename}
<b>Started by:-</b> ${tg_username}
EOT
  if [ $finish = 0 ] ; then
    telegram-send --format html "$msg" --config /ryzen.conf
  fi
}

function setVar {
    hours=$((i/3600))
    minutes=$(( $((i/60)) - $((hours*60))))
    seconds=$(( i - $((hours*60*60)) -  $((minutes*60))))
    if [ $hours = 1 ]; then
        h="Hour"
    else
       h="Hours"
    fi
    if [ $minutes = 1 ]; then
        m="Minute"
    else
        m="Minutes"
    fi
    if [ $seconds = 1 ]; then
        s="Second"
    else
        s="Seconds"
    fi
}

i=0
echo -n "Test Line might be deleted"
while { set -C; ! 2>/dev/null > /tmp/manlocktest.lock; }; do
  ((i=i+1))
  uname2=$(ls -l /tmp/manlocktest.lock | awk '{print $3}');
  setVar
  if [ $uname2 = $USER ]; then
        echo -e "Warning you can't wait while you are building"
        exit 1
  elif [ $i -gt 3600 ]; then
        hours=$((i/3600))
        minutes=$(( $((i/60)) - $((hours*60))))
        seconds=$(( i - $((hours*60*60)) -  $((minutes*60))))
        pr="$hours $h $minutes $m $seconds $s      "
  elif [ $i -lt 60 ]; then
        pr="$i $s  "
  else
        minutes=$((i/60))
        seconds=$(( i - $((minutes*60))))
        pr="$minutes $m $seconds $s    "
  fi

  echo -n -e "\r${uname2} Building. Waiting for $pr"
  sleep 10
done
trap finish EXIT SIGINT

echo -e "\rBuild starting thank you for waiting"


#Start Counting build time after build started we don't want wait time included
START=$(date +%s)
BUILDFILE="buildlog"_$START.txt

mkdir -p /home/${user}/downloads/buildlogs/
touch /home/${user}/downloads/buildlogs/${BUILDFILE}
BLINK="http://${user}.ryzenbox.me/buildlogs/${BUILDFILE}"
# Send message to TG
read -r -d '' msg <<EOT
<b>Build Started</b>
<b>Device:-</b> ${device_codename}
<b>Started by:-</b> ${tg_username}
<b>Console log:-</b> <a href="${BLINK}">here</a>
EOT

telegram-send --format html "$msg" --config /ryzen.conf

# Colors makes things beautiful
export TERM=xterm

    red=$(tput setaf 1)             #  red
    grn=$(tput setaf 2)             #  green
    blu=$(tput setaf 4)             #  blue
    cya=$(tput setaf 6)             #  cyan
    txtrst=$(tput sgr0)             #  Reset

# Ccache
if [ "$use_ccache" = "yes" ];
then
echo -e ${blu}"CCACHE is enabled for this build"${txtrst}
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_DIR=/home/$user/ccache
ccache -M 75G
fi

if [ "$use_ccache" = "clean" ];
then
export CCACHE_EXEC=$(which ccache)
export CCACHE_DIR=/home/$user/ccache
ccache -C
export USE_CCACHE=1
ccache -M 75G
wait
echo -e ${grn}"CCACHE Cleared"${txtrst};
fi

rm -rf ${OUT_PATH}/*.zip #clean rom zip in any case

# Time to build
source build/envsetup.sh
lunch "$lunch"_"$device_codename"-"$build_type"

# Clean build
if [ "$make_clean" = "yes" ];
then
make clean && make clobber
wait
echo -e ${cya}"OUT dir from your repo deleted"${txtrst};
fi

if [ "$make_clean" = "installclean" ];
then
make installclean
rm -rf ${OUT_PATH}/${ROM_ZIP}
wait
echo -e ${cya}"Images deleted from OUT dir"${txtrst};
fi

if [ "$make_clean" = "deviceclean" ];
then
make deviceclean
rm -rf ${OUT_PATH}/${ROM_ZIP}
wait
echo -e ${cya}"Device dir deleted from OUT dir"${txtrst};
fi

make bacon -j16 |& tee  "/home/${user}/downloads/buildlogs/${BUILDFILE}"

END=$(date +%s)
TIME=$(echo $((${END}-${START})) | awk '{print int($1/60)" Minutes and "int($1%60)" Seconds"}')

ROM=${OUT_PATH}/ShapeShiftOS*.zip
if [ -f $ROM ]; then

cp $ROM /home/${user}/downloads/
filename="$(basename $ROM)"
LINK="http://${user}.ryzenbox.me/${filename}"
read -r -d '' suc <<EOT
<b>Build Finished</b>
<b>Time:-</b> ${TIME}
<b>Device:-</b> ${device_codename}
<b>Started by:-</b> ${tg_username}
<b>Download:-</b> <a href="${LINK}">here</a>
EOT

else

# Send message to TG
cp out/error.log /home/${user}/downloads/error.txt
read -r -d '' suc <<EOT
<b>Build Errored</b>
<b>Time:-</b> ${TIME}
<b>Device:-</b> ${device_codename}
<b>Started by:-</b> ${tg_username}
<b>Check error:-</b> <a href="http://${user}.ryzenbox.me/error.txt">here</a>
EOT

fi

if [ $stopped = 0 ] ; then
  telegram-send --format html "$suc" --config /ryzen.conf
fi
finish=1
