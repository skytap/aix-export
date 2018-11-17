#!/bin/ksh


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

## Will set the imported VM name to be the same as the hostname
LPAR_NAME=$(hostname)

## Test for disks in ODM
echo ""
echo "Locating Disks:"
for arg;do
   DISK=`lscfg -l $arg`
   if [ $? -ne 0 ]; then
      >&2 echo "FAILED: unable to detect device $arg, exiting script"
      exit 1 #exit script due to failure state, unable to find disk
   fi
   DISK_ALLOCATION=$(getconf DISK_SIZE /dev/$arg)
   echo "Found device $arg, $DISK_ALLOCATION MB"
done

## Prompt for user response of disk size before proceeding
echo ""
echo "Disk images will be created uncompressed in local directory."
echo "Create these image(s) in your local directory? (Yes/No)"
read  answer
case $answer in
   yes|Yes|y)
	   ;;
   no|n|No)
      exit 2 #exiting due to user response, no errors
      ;;
esac

## Create disk images
echo ""
for arg;do
   echo "Creating disk $LPAR_NAME-$arg.img"
   dd if=/dev/$arg of=$LPAR_NAME-$arg.img bs=64K conv=noerror,sync
done
echo 'Disks images created'

## Run make_ovf.ksh script
( ${0%/*}/make_ovf.ksh "$@" )
if [ $? -ne 0 ]; then
   >&2 echo "FAILED: error with ovf creation, exiting script"
   exit 1 #exit script due to failure state, received failure from make_ovf script
fi

exit 0 #successful exit
