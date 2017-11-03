#!/bin/ksh


########################################################################
## Copyright 2017 Skytap Inc.
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
## FIND AND DECLAIR VARIABLES
########################################################################

set -A INPUT "$@"
## uncomment following block to print out inputs
# for arg;do
#    print $arg
# done

## Test for disks in ODM
echo ""
echo "Disks:"
for arg;do
   DISK=`lscfg -l $arg`
   if [ $? -ne 0 ]; then
      echo “FAILED: unable to detect device $arg”
      exit 1
   fi
   DISK_ALLOCATION=$(getconf DISK_SIZE /dev/$arg)
   echo "Found device $arg, $DISK_ALLOCATION MB"
done

## Check to proceed
echo ""
echo "Disk images will be created uncompressed in local directory."
echo "Create these image(s)? (Yes/No)"
read  answer
case $answer in
   yes|Yes|y)
#      echo "responded yes"
      ;;
   no|n|No)
#      echo "responded no"
      exit 2 #non-error early exit
      ;;
esac

## Create disk images
echo ""
for arg;do
   echo "Creating disk $arg.img"
   dd if=/dev/$arg of=$arg.img 2> /dev/null
done
echo 'Disks images created'

## Run make_ovf.ksh script
./make_ovf.ksh "$@"
if [ $? -ne 0 ]; then
   echo “FAILED: creation of ovf file”
   exit 1
fi

exit 0