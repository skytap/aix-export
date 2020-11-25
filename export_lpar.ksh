#!/bin/ksh

## v2.5.5
## Images raw disk devices - /dev/rhdisk#
########################################################################
## Copyright 2018 Skytap Inc.
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##     http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
########################################################################


## Generates the disk images required for import into Skytap cloud
## Expect make_ovf script to be within same directory to call at end
## Pass desired physical volumes into script starting with rootvg's volume
##
## It is recommended that the rootvg physical volume be an inactive
## rootvg created by alt_disk_copy


########################################################################
## FIND AND DECLARE VARIABLES
########################################################################

set -A INPUT "$@"

## Check for empty drive parameters 
if [ $# -eq 0 ];then
   echo "No drive parameters were passed.  Exiting script"
   exit 1
fi

## Get free space of filesystem for current directory
typeset -i FSSZ=$(df . | awk -v i=2 -v j=3 'FNR == i {print $j}')
FSSZ=$FSSZ/2/1024

## Will set the imported VM name to be the same as the hostname
LPAR_NAME=$(hostname)

## Get ulimit file size setting
STFSIZE=$(ulimit -f)

typeset -i TOTDR=0
## Test for disks in ODM
echo ""
echo "Locating Disks:"
for arg;do
   DISK=`lscfg -l $arg`
   if [ $? -ne 0 ]; then
      >&2 echo "FAILED: unable to detect device $arg, exiting script"
      exit 1 #exit script due to failure state, unable to find disk
   fi


   ## Verify disk image size can be written 
   DISK_ALLOCATION=$(getconf DISK_SIZE /dev/$arg)
   if [ "$STFSIZE" != "unlimited" ]; then
      typeset -i STFZ2=$STFSIZE*512
      typeset -i D2=$(getconf DISK_SIZE /dev/$arg)*1024*1024
      if [ $D2 -gt $STFZ2 ]; then
         echo ""
         echo "**Size Mismatch**"
         echo "  fsize=$STFSIZE is too small to write a disk image for device: $arg - $(getconf DISK_SIZE /dev/$arg) MB"
         echo "  set fsize = -1 for unlimited in the '/etc/security/limits' file until the imaging is complete"
         echo "  exiting script"
         exit 1 #exit due to fsize mismatch with disk image size
      else
	 TOTDR=$(($TOTDR+$(getconf DISK_SIZE /dev/$arg)))
         echo "Found device $arg, $DISK_ALLOCATION MB"
      fi
   else
      TOTDR=$(($TOTDR+$(getconf DISK_SIZE /dev/$arg)))
      echo "Found device $arg, $DISK_ALLOCATION MB"
   fi

done

## Prompt for user response of disk size before proceeding
echo ""
echo "Disk images will be created in directory: $(pwd | cat)" 
echo "Create image(s) in this directory? (Y)es/(N)o/(C)hange"
read  answer
case $answer in
   yes|Yes|y|Y)
      WRKDIR=$(pwd | cat)
	   ;;
   no|n|No)
      echo "exiting on No"
      exit 2 #exiting due to user response, no errors
           ;;
   Change|c|C|change)
      echo "Enter the path to your destination directory."
      read answer
      WRKDIR=$answer
           ;;
esac

## Get free space of filesystem for selected directory
typeset -i FSSZ=$(df $WRKDIR | awk -v i=2 -v j=3 'FNR == i {print $j}')
FSSZ=$FSSZ/2/1024

## Verify destination storage space
TOTDR=$(($TOTDR*2))
if [ $TOTDR -gt $FSSZ ]; then
   echo ""
   echo "**Insufficient Space**"
   echo "The current filesystem does not have sufficient space to image and compress the LPAR."
   echo "Increase the filesystem space or select another filesystem with at a minimum of $TOTDR MB of free space"
   exit 1 #exit due to insufficient space
fi

## Create disk images
echo " "
echo 'Creating disk image(s)'

export WRKDIR=$WRKDIR

echo ""
for arg;do
   echo "Creating disk $LPAR_NAME-$arg.img"
   dd if=/dev/r$arg of=$WRKDIR/$LPAR_NAME-$arg.img bs=1M conv=noerror,sync #bs=1M instead of bs=64 to improve imaging speed
done
echo 'Disks images created'
date

## Run make_ovf.ksh script
( ${0%/*}/make_ovf.ksh "$@" )
if [ $? -ne 0 ]; then
   >&2 echo "FAILED: error with ovf creation, exiting script"
   exit 1 #exit script due to failure state, received failure from make_ovf script
fi

echo ""

## Create tar and compress
echo 'Creating tar file: ' $WRKDIR/$LPAR_NAME
MKTAR=$LPAR_NAME'.ovf'
for arg;do
    MKTAR=$(echo $MKTAR $LPAR_NAME-$arg'.img')
done

PZ=$(pwd | cat)

cd $WRKDIR
tar -cvf $WRKDIR/$LPAR_NAME $MKTAR

## Validate tar file, compress, and clean up
echo ""
echo 'Validating tar file: ' $WRKDIR/$LPAR_NAME
tar -tvf $WRKDIR/$LPAR_NAME
echo 'tar exit status: ' $?
if [ $? -ne 0 ]; then
    echo "Tar validation failed."
    echo "Try manually taring the files again or"
    echo "upload the indiviual .img and .ovf files."
    exit 1
else
    ## Remove .img and .ovf files after .ova creation
    echo ""
    echo 'Cleaning up LPAR imaging files'
    for arg; do
        ##rm $WRKDIR/*.img
        echo 'Deleting file: ' $WRKDIR/$LPAR_NAME-$arg.img
        rm $WRKDIR/$LPAR_NAME-$arg.img
    done
    echo 'Deleting file: ' $WRKDIR/$LPAR_NAME.ovf
    rm $WRKDIR/$LPAR_NAME.ovf

    echo ""
    echo 'Compressing Files'
    echo 'Compressing file: ' $WRKDIR/$LPAR_NAME.ova
    cd $PZ
    ./pigz $WRKDIR/$LPAR_NAME 
    mv $WRKDIR/$LPAR_NAME.gz $WRKDIR/$LPAR_NAME.ova
fi

echo ""
echo '***LPAR imaging complete***'
exit 0 #successful exit
