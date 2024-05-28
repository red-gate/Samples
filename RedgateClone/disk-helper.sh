#!/bin/bash

echo '------------------------------------------------------------------------------------------------------------------------'
echo 'Use this guide to identify the host directory and naming pattern for the the disks to use with Redgate Clone. '
echo 'The naming pattern may include one or more unformatted disks. It must not include the disk containing the OS.'
echo 'This script ignores all partitions inside a disk because we cannot use a partioned disk. Please use unformatted disks.'
echo 'We look for disks with fdisk -l, then we look for scsi disks.'
echo 'You can use the host and naming pattern from the plain disks or the scsi lun mappings.'
echo ''
echo 'To use more than one disk, read our documentation on adding more than one disk.'
echo ''
echo 'To view your disk information yourself type: sudo fdisk -l'
echo '-------------------------------------------------------------------------------------------------------------------------'
echo ''

disklist=()

echo ''
echo 'Scanning your disks with command, fdisk -l'
echo ''

while read line; do
  result=$(sudo fdisk -l "$line")
  size=$(echo $result | cut -d',' -f 1 | cut -d':' -f 2)
  if [[ "$result" == *"type: gpt"* ]] || [[ "$result" == *"type: MBR"*  ]] || [[ "$result" == *"type: dos"*  ]] || [[ "$result" == *"root"*  ]]; then
    echo  "Disk $line, size$size, is formatted. It may be used by the OS. Do not include this in the naming pattern."
  elif ls -al /dev/disk/by-partuuid/ | grep -q "${line##*/}"; then
    echo "Disk $line, size:$size is partioned. Do not use it."     
  else
      disk=$(echo $line | cut -d'/' -f 3)
      path=$(echo $line | cut -d'/' -f 2)
      echo "Disk $line, size$size, is not formatted by linux and ok to use for redgate clone. /$path is the host directory and $disk is the name."
      disklist+=("$disk")
  fi
done <<<$(sudo fdisk -l | grep 'Disk /dev' | grep -v 'loop' | cut -d':' -f 1 | cut -d' ' -f 2)
echo ''
echo 'Found no more disks.'
echo ''

if [ -f /proc/scsi/scsi ] && grep -q -F "scsi" /proc/scsi/scsi ; then
  echo "Scsi disks have been detected."
  echo ''
fi

if [ -d /dev/disk/azure/scsi1 ]; then
  echo "Because this is an Azure VM, use a naming pattern that includes the wanted scsi disks found below (lun). The host directory to use with the scsi disks is "/dev/disk/azure/scsi1""
  echo "These are the scsi disk we detected: "
fi

for disk in "${disklist[@]}"
do
  if [ -f /proc/scsi/scsi ] && grep -q -F "scsi" /proc/scsi/scsi ; then
    mapping=$(ls -l /sys/block/*/device | grep "$disk")
    lundisk=$(echo $mapping | cut -d':' -f 5)
    echo "lun$lundisk is mapped to $disk. You can use lun$lundisk in the naming pattern."
  fi
done         
echo ""