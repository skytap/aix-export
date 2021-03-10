# POWER AIX Export Script

Copyright 2020 Skytap Inc.

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
- The script and pigz need to be made available on the AIX LPAR and should be in the same directory.
    - Note: The gzip libraries are required and are generally available in a default AIX installation.
- Script output, in the form of an .ova file, will be located in the output directory selected via the prompt.  The output location can be local or remote via NFS.
- The scripts do not perform destructive tasks and will not clean up any files they generate.
- Only the disk images specified when running export\_lpar will generate disk images and these images will include unused space on the disk (do not have a way to flatten the images out at this time).
- The space required to image an LPAR is double the space of the drives being imaged. This is to accomodate imaging and compression.

## There is one script involved:
```
export_lpar.ksh
```

## Background
This script is intended to produce a compress packaged .ova file of the LPAR. The output of this script is IMG files which are the disk images for the LPAR, one of these IMG files must represent the rootvg. It will also generate an OVF file which is the descriptor of the LPAR. The OVF will be used at time of import by Skytap to create the LPAR to specifications.

## How to use this script
- Ensure a rootvg is available to be copied. It is recommended to use alt\_disk\_copy command to create an up-to-date version of rootvg that can be used to create the root disk image.
- Workloads on disks you want to create images of should be quiesced. Optional to further varyoffvg the physical volumes.
- Within the directory you want your images to be created, run export\_lpar.ksh with physical volume names as arguments, starting with your rootvg.
- The LPAR file, .ova, can be uploaded and imported directly into Skytap via SFTP or Cloud Object Storage.
```
Import CheatSheet:
disks consumption is quite massive (in part because we dont have an option to compress the disk images yet).
make_ovf assumes a couple things. that the disk images are already created, and it is being run on the system that the disks are on.
what you need to do:
1. create or update alt_disk_copy to get rootvg that is not in use. Example:
# alt_disk_copy -d hdisk1 -B
2. run export_lpar with the disks as arguments. output will be disk images and hostname.ovf Example:
# ./export_lpar.ksh hdisk1 hdisk2 hdisk3
3. upload and import to Skytap import site, flagging the job for Power VM. Account must be Power enabled.
```

## export_lpar.ksh
export\_lpar expects to be passed a string of physical volume names (eg, hdisk0, hdisk1...). It will then validate it has access to those disks and use dd to create IMG files for each disk. The IMG files will be created in your present working directory. The first physical volume specified needs to be rootvg, it is strongly recommended that the underlying physical volume for rootvg be an up-to-date copy created from alt\_disk\_copy. When the image files are created, it will then automatically run make\_ovf with the same physical volume arguments.
