# POWER AIX Export Script

Copyright 2018 Skytap Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Things to know before getting started:
- Both scripts need to be made available on the AIX lpar and should be in the same directory (export\_lpar runs make\_ovf).
- Script output, including disk images and ovf file will be placed in the current working directory they are run from.
- The scripts do not perform destructive tasks and will not clean up any files they generate (make\_ovf will overwrite the output ovf file with the same name).
- Only the disk images specified when running export\_lpar will generate disk images and these images will include unused space on the disk (do not have a way to flatten the images out at this time).
- Disk order is not guaranteed at import (yet). There is a risk that the rootvg (boot disk) will not be correctly flagged at time of import, needs further investigation.
- Disks will consume a LOT of space. Expect the output disk images to be the full size of any physical volumes targeted for export.

## There are two scripts involved:
```
export_lpar
make_ovf
```

## Background
These scripts are intended to produce two types of output. The output of these scripts are IMG files which are the disk images for the lpar, one of these IMG files must represent the rootvg. It will also generate an OVF file which is the descriptor of the lpar. The OVF will be used at time of import by Skytap to create the lpar to specifications.

export\_lpar will automatically run make\_ovf when it is complete. make\_ovf can be run separately if desired.

## How to use these scripts
- Ensure a rootvg is available to be copied. It is recommended to use alt\_disk\_copy command to create an up-to-date version of rootvg that can be used to create the root disk image.
- Workloads on disks you want to create images of should be quiesced. Optional to further varyoffvg the physical volumes.
- Within the directory you want your images to be created, run export\_lpar.ksh with physical volume names as arguments, starting with your rootvg. (THIS WILL TAKE A LONG TIME)
- When export\_lpar.ksh is complete, it will automatically call make\_ovf.ksh with the same physical volume specified when running export_lpar.ksh.
- (optional) At this point the OVF and accompanying IMG files can be can be bundled in a tar file and compressed, the bundle should be appended with OVA.
- The LPAR files (OVF+IMG or OVA) can be uploaded and imported directly into Skytap via SFTP, or shipped to Skytap's office and we can assist with import efforts.

```
Import CheatSheet:
disks consumption is quite massive (in part because we dont have an option to compress the disk images yet).
make_ovf assumes a couple things. that the disk images are already created, and it is being run on the system that the disks are on.
what you need to do:
1. create or update alt_disk_copy to get rootvg that is not in use. Example:
# alt_disk_copy -d hdisk1 -B
2. run export_lpar with the disks as arguments. output will be disk images and hostname.ovf Example:
# ./export_lpar.ksh hdisk1 hdisk2 hdisk3
3. (optional) you can bundle the files together with tar to bundle the files and compress empty disk sections. Note: if the compression flag is not native to your tar, compression can be performed with an alternate command.
# tar -czvf powervm.ova hostname.ovf powervm-hdisk1.img powervm-hdisk2.img powervm-hdisk3.img
  OR
# tar -cvf - powervm.ovf powervm-hdisk1.img powervm-hdisk2.img powervm-hdisk3.img | gzip > powervm.ova
4. upload and import to Skytap import site, flagging the job for Power VM. Account must be Power enabled.
```

## export_lpar.ksh
export\_lpar expects to be passed a string of physical volume names (eg, hdisk0, hdisk1...). It will then validate it has access to those disks and use dd to create IMG files for each disk. The IMG files will be created in your present working directory. The first physical volume specified needs to be rootvg, it is strongly recommended that the underlying physical volume for rootvg be an up-to-date copy created from alt\_disk\_copy. When the image files are created, it will then automatically run make\_ovf with the same physical volume arguments.

## make_ovf.ksh
make\_ovf expects to be passed a string of physical volumes (eg, hdisk0, hdisk1) that should be included within the OVF file. It will detect the number of virtual processors (not physical), RAM allocation, active ethernet adapters, and it will name the exported lpar and OVF file after the lpar hostname. Disks passed into the script are evaluated to exist and then also included in the output OVF. Other lpar details are not captured in the OVF. This script will be automatically called when export_lpar is complete, it can also be run as a stand-alone script to only generate an OVF file.
