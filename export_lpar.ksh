#!/bin/ksh

## v2.5.6
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

echo "" 

########################################################################
## BEGIN CREATE OVF FILE
########################################################################

## Creates AIX OVF file for import into Skytap cloud
## Pass desired physical volumes into script starting with rootvg's volume

## Find number of virtual processors
VIRTUAL_PROCESSORS=$(prtconf | awk '/Number Of Processors/{print $4}')

## Find amount of allocated ram
RAM_ALLOCATION=$(lparstat -i | awk '/Online Memory/{print $4}')

## Find all in-use ethernet adapters
ETHERNET_ADAPTERS=$(netstat -i | awk '/en/{print $1}' | awk '!x[$0]++')

##

echo ""
echo 'Creating OVF file: '$WRKDIR/$LPAR_NAME'.ovf'
> $WRKDIR/$LPAR_NAME'.ovf'
echo '<?xml version="1.0" encoding="UTF-8"?>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '<ovf:Envelope xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:skytap="http://help.skytap.com" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_VirtualSystemSettingData.xsd http://schemas.dmtf.org/ovf/envelope/1 http://schemas.dmtf.org/ovf/envelope/1/dsp8023_1.1.0.xsd http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2.22.0/CIM_ResourceAllocationSettingData.xsd">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    <ovf:References>' >> $WRKDIR/$LPAR_NAME'.ovf'
for arg;do
   echo '        <ovf:File ovf:id="file_'$arg'" ovf:href="'$LPAR_NAME-$arg'.img"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
done
echo '    </ovf:References>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    <ovf:DiskSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '        <ovf:Info>Virtual disk information</ovf:Info>' >> $WRKDIR/$LPAR_NAME'.ovf'
for arg;do
   typeset -i DISK_ALLOCATION
   DISK_ALLOCATION=$(ls -l $WRKDIR/$LPAR_NAME-$arg.img | awk '{print $5}')
   echo '        <ovf:Disk ovf:fileRef="file_'$arg'" ovf:diskId="disk_'$arg'" ovf:capacity="'$DISK_ALLOCATION'"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
done
echo '    </ovf:DiskSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    <ovf:VirtualSystemCollection ovf:id="AIX">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '        <ovf:VirtualSystem ovf:id="AIX MachineName">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            <ovf:Name>'$LPAR_NAME'</ovf:Name>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            <ovf:OperatingSystemSection ovf:id="9">' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ovf:Info/>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ovf:Description>AIX</ovf:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ns0:architecture xmlns:ns0="ibmpvc">ppc64</ns0:architecture>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            </ovf:OperatingSystemSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            <ovf:VirtualHardwareSection>' >> $WRKDIR/$LPAR_NAME'.ovf' >> $WRKDIR/$LPAR_NAME'.ovf'
typeset -i COUNT=1
for e in $ETHERNET_ADAPTERS;do
   SLOT=$(lsdev -l $(echo $e | sed 's/en/ent/') -F "physloc"| sed -n 's/.*-C\([^-]*\)-.*/\1/p')
   NETADDR=$(lsattr -E -l $e -a netaddr | awk '{print $2}')
   NETMASK=$(lsattr -E -l $e -a netmask | awk '{print $2}')
   echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:Description>Ethernet adapter '$COUNT'</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ElementName>Network adapter '$COUNT'</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:InstanceID>10'$COUNT'</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ResourceType>10</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
   if [ -n "$SLOT" ]; then
      echo '                    <skytap:Config skytap:value="'$SLOT'" skytap:key="slotInfo.cardSlotNumber"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   if [ -n "$NETADDR" ]; then
      echo '                    <skytap:Config skytap:value="'$NETADDR'" skytap:key="networkInterface.ipAddress"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   if [ -n "$NETMASK" ]; then
      echo '                    <skytap:Config skytap:value="'$NETMASK'" skytap:key="networkInterface.ipAddress"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   ((COUNT=COUNT+1))
done
typeset -i COUNT=1
for arg;do
   SLOT=$(lsdev -l $arg -F "physloc" | sed -n 's/.*-C\([^-]*\)-.*/\1/p')
   echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:Description>Hard disk</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ElementName>Hard disk '$COUNT'</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:HostResource>ovf:/disk/disk_'$arg'</rasd:HostResource>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:InstanceID>100'$COUNT'</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
   echo '                    <rasd:ResourceType>17</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
   if [ -n "$SLOT" ]; then
      echo '                    <skytap:Config skytap:value="'$SLOT'" skytap:key="slotInfo.cardSlotNumber"/>' >> $WRKDIR/$LPAR_NAME'.ovf'
   fi
   echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
   ((COUNT=COUNT+1))
done
echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Description>Number of Virtual CPUs</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ElementName>'$VIRTUAL_PROCESSORS' virtual CPU(s)</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:InstanceID>7</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Reservation>0</rasd:Reservation>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ResourceType>3</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:VirtualQuantity>'$VIRTUAL_PROCESSORS'</rasd:VirtualQuantity>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Weight>0</rasd:Weight>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                <ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Description>Memory Size</rasd:Description>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ElementName>'$RAM_ALLOCATION' MB of memory</rasd:ElementName>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:InstanceID>8</rasd:InstanceID>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Reservation>0</rasd:Reservation>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:ResourceType>4</rasd:ResourceType>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:VirtualQuantity>'$RAM_ALLOCATION'</rasd:VirtualQuantity>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                    <rasd:Weight>0</rasd:Weight>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '                </ovf:Item>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '            </ovf:VirtualHardwareSection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '        </ovf:VirtualSystem>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '    </ovf:VirtualSystemCollection>' >> $WRKDIR/$LPAR_NAME'.ovf'
echo '</ovf:Envelope>' >> $WRKDIR/$LPAR_NAME'.ovf'

echo 'OVF Completed Successfully'

########################################################################
## END CREATE OVF FILE
########################################################################


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
