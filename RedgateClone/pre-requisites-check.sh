#!/usr/bin/env bash
#############################################################################################################################
# Name                 : prerequisite-check.sh
# Description          : Checks a Linux machine against the Redgate Clone prerequisites and requirements
#                        i.e. the items listed here https://documentation.red-gate.com/x/nANsC
#############################################################################################################################
 
###################################################### Requirements #########################################################
 
expected_os_name_ubuntu="ubuntu"
expected_os_name_rhel="red hat enterprise linux"
minimum_os_version_ubuntu="22.04"
minimum_os_version_rhel="8.0"
minimum_cpu_count=8
minimum_ram_size_in_gib=16
expected_system_disk_partition_table_type="gpt"
minimum_system_disk_size_human_readable="80Gi"
minimum_data_disk_size_human_readable="100Gi"
minimum_root_size_human_readable="2Gi"
minimum_home_size_human_readable="4Gi"
minimum_tmp_size_human_readable="3Gi"
minimum_var_size_human_readable="50Gi"
minimum_usr_size_human_readable="8Gi"
 
###################################################### Script setup #########################################################
 
set -Eeuo pipefail
 
if [[ $(uname | tr '[:upper:]' '[:lower:]') != "linux" ]]; then
    echo "This script can only be run on a Linux environment, but environment type $(uname) was detected."
    exit 1
fi
 
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script requires root permissions. Please rerun using sudo."
    exit 1
fi
 
errors=()
 
function report_and_exit() {
    echo
    if [ ${#errors[@]} != 0 ]; then
        echo "Found the following errors..."
        for error in "${errors[@]}"; do
            echo "    • $error"
        done
        exit 1
    else
        echo "No errors were found!"
        exit 0
    fi
}
 
section_start_error_count=0
 
function start_section() {
    section_start_error_count=${#errors[@]}
    printf "    Checking %s requirements... " "$1"
}
 
function end_section() {
    if [[ $section_start_error_count -eq ${#errors[@]} ]]; then
        echo "OK"
    else
        echo "FAIL"
    fi
}
 
echo "Checking Redgate Clone host VM pre-requisites (https://documentation.red-gate.com/x/kgARCQ)..."
 
####################################################### OS checks ###########################################################
 
start_section "OS"
 
if ls /etc/*-release 1> /dev/null 2>&1; then
    os_name=$(cat /etc/*-release | grep "^NAME=" | cut -d'"' -f2 | tr '[:upper:]' '[:lower:]')
    os_version=$(cat /etc/*-release | grep "^VERSION_ID=" | cut -d= -f2 | xargs)
 
    if [ "$os_name" == "$expected_os_name_ubuntu" ] || [ "$os_name" == "$expected_os_name_rhel" ]; then
        if [[ -z "${os_version// }" ]]; then
            errors+=("The $os_name version could not be detected. Redgate Clone requires at least version $minimum_os_version.")
        else
            is_rhel8=
            if [ "$os_name" == "$expected_os_name_ubuntu" ]; then
                minimum_os_version=$minimum_os_version_ubuntu
            else
                minimum_os_version=$minimum_os_version_rhel
                major_version=$(printf %.1s "$os_version")
                if [ "$major_version" == "8" ]; then
                    is_rhel8=true
                fi
            fi
 
            if [[ $(printf "%s\n%s" "$minimum_os_version" "$os_version" | sort -V | head -n1) != "$minimum_os_version" ]]; then
                errors+=("The $os_name version must be at least $minimum_os_version but was detected to be $os_version.")
            fi
        fi
    else
        errors+=("The operating system must be $expected_os_name_rhel or $expected_os_name_ubuntu but it was detected to be $os_name.")
        end_section
        report_and_exit # Exit early as the other checks may not work as expected.
    fi
else
    errors+=("The operating system must be $expected_os_name_rhel or $expected_os_name_ubuntu but the distribution could not be detected. The uname command returns \"$(uname -a)\".")
    end_section
    report_and_exit # Exit early as the other checks may not work as expected.
fi
 
end_section
 
#################################################### Hardware checks ########################################################
 
start_section "CPU"
 
cpu_count=$(nproc --all)
 
if [ "$cpu_count" -lt "$minimum_cpu_count" ]
then
    errors+=("Redgate Clone requires a minimum of $minimum_cpu_count vCPUs, but $cpu_count were detected.")
fi
 
end_section
 
start_section "RAM"
 
if [[ $(which dmidecode) ]]; then
    ram_size_in_gib=$(dmidecode -t memory | grep "^[[:space:]]Size:" | cut -d: -f2 | tr -d ' B' | grep -v -x -F "NoModuleInstalled" | numfmt --from=iec | awk 'BEGIN {count=0;} {count+=$1;} END {print count/1073741824;}')
    if [ "$ram_size_in_gib" -lt "$minimum_ram_size_in_gib" ]
    then
        errors+=("Redgate Clone requires a minimum of ${minimum_ram_size_in_gib}Gi RAM, but ${ram_size_in_gib}Gi was detected.")
    fi
else
    errors+=("The amount of RAM could not be detected because the dmidecode utility is missing. Redgate Clone requires a minimum of ${minimum_ram_size_in_gib}Gi RAM.")
fi
 
end_section
 
###################################################### Disk checks ##########################################################
 
start_section "storage"
 
minimum_system_disk_size=$(numfmt --from=auto $minimum_system_disk_size_human_readable)
minimum_data_disk_size=$(numfmt --from=auto $minimum_data_disk_size_human_readable)
 
system_disk=$(lsblk --bytes --output NAME,MOUNTPOINT,PKNAME --list --paths | awk '{if($2=="/")print $3}')
system_disk_size=$(lsblk --bytes --output NAME,SIZE --list --paths | awk '{if($1=="'"$system_disk"'")print $2}')
 
if [ "$is_rhel8" = true ]; then    
    system_partition_table_type=$(sudo fdisk -l 2> /dev/null | awk '/Disklabel type:/ {print $3}')
else
    system_partition_table_type=$(lsblk --output NAME,PTTYPE --list --paths | awk '{if($1=="'"$system_disk"'")print $2}')
fi
 
if [ "$((system_disk_size))" -lt "$((minimum_system_disk_size))" ]; then
    system_disk_size_human_readable=$(numfmt --to=iec-i "$system_disk_size")
    errors+=("The system disk needs to be at least $minimum_system_disk_size_human_readable in size. Disk $system_disk was detected to be the system disk but its size is only $system_disk_size_human_readable.")
fi
 
if [ "$system_partition_table_type" != "$expected_system_disk_partition_table_type" ]; then
   errors+=("The system disk's partition table type must be $expected_system_disk_partition_table_type but was detected to be $system_partition_table_type.")
fi
 
if [ "$is_rhel8" = true ]; then
    possible_data_disks=$(lsblk --bytes --output NAME,SIZE,TYPE | awk '($2 >= '"$minimum_data_disk_size"' && $3 == "disk") {print "/dev/"$1;}' | tr ' ' '\n')
else
    possible_data_disks=$(lsblk --bytes --output NAME,SIZE,TYPE,PATH | awk '($2 >= '"$minimum_data_disk_size"' && $3 == "disk") {print $4;}' | tr ' ' '\n')
fi
 
data_disks=()
declare -A filesystems
 
for blockdevice in $possible_data_disks; do
    filesystem_count=$(lsblk --noheadings --fs --output NAME,FSTYPE --list "$blockdevice" | awk 'BEGIN {count=0;} {if ($2) count+=1} END {print count;}')
    if [ "$filesystem_count" -eq 0 ]
    then
        data_disks+=("$blockdevice")
    else
        filesystems[$blockdevice]=$filesystem_count
    fi
done
 
if [ ${#data_disks[@]} == 0 ]; then
    filesystem_list=""
    for key in "${!filesystems[@]}"; do
        filesystem_list+=" Device $key is large enough but already has ${filesystems[$key]} existing filesystems."
    done
    errors+=("No disks were detected that have a size greater than $minimum_data_disk_size_human_readable and have no existing filesystems.$filesystem_list")
fi
 
 
# check if they are using LVM volumes and if so if there is enough space assigned to the root, home, tmp, var and usr directories
 
if command -v lvs &> /dev/null
then
    if [ -n "$(lvs)" ]; then
      root_lv=$(lsblk --output NAME,MOUNTPOINT --list --paths | awk '{if($2=="/")print $1}')
      home_lv=$(lsblk --output NAME,MOUNTPOINT --list --paths | awk '{if($2=="/home")print $1}')
      tmp_lv=$(lsblk --output NAME,MOUNTPOINT --list --paths | awk '{if($2=="/tmp")print $1}')
      var_lv=$(lsblk --output NAME,MOUNTPOINT --list --paths | awk '{if($2=="/var")print $1}')
      usr_lv=$(lsblk --output NAME,MOUNTPOINT --list --paths | awk '{if($2=="/usr")print $1}')
 
      check_lv() {
          lv=$1
          minimum_size=$2
          directory=$3
 
          if [[ $lv == *"/dev/mapper"* ]]; then
              lv_size=$(lsblk --bytes --output NAME,SIZE --list --paths | awk '{if($1=="'"$lv"'")print $2}')
              
              if [ "$((lv_size))" -lt "$((minimum_size))" ]; then
                  lv_size_human_readable=$(numfmt --to=iec-i "$lv_size")
                  errors+=("The $directory directory needs to be at least $(numfmt --to=iec-i "$minimum_size") in size. Logical volume $lv was detected to be the $directory directory but its size is only $lv_size_human_readable.")
              fi
          else
              errors+=("The $directory directory is not on an LVM.")
          fi
      }
 
 
      minimum_root_size=$(numfmt --from=auto $minimum_root_size_human_readable)
      minimum_home_size=$(numfmt --from=auto $minimum_home_size_human_readable)
      minimum_tmp_size=$(numfmt --from=auto $minimum_tmp_size_human_readable)
      minimum_usr_size=$(numfmt --from=auto $minimum_usr_size_human_readable)
      minimum_var_size=$(numfmt --from=auto $minimum_var_size_human_readable)
 
      check_lv "$root_lv" "$minimum_root_size" "/"
      check_lv "$home_lv" "$minimum_home_size" "/home"
      check_lv "$tmp_lv" "$minimum_tmp_size" "/tmp"
      check_lv "$var_lv" "$minimum_var_size" "/var"
      check_lv "$usr_lv" "$minimum_usr_size" "/usr"
    fi
fi
 
end_section
 
################################################# Internet connectivity #####################################################
 
start_section "Internet connectivity"
 
set +e
if ! curl --silent --head --retry 3 --output /dev/null http://www.google.com/; then
    errors+=("Internet connectivity was not detected.")
fi
set -e
 
end_section
 
################################################# Installation script availability #####################################################
 
start_section "Installation script availability"
 
readonly INSTALLATION_TEST_URL=https://k8s.kurl.sh/cloning-capability-app
 
set +e
if ! curl --silent --head --retry 3 --output /dev/null $INSTALLATION_TEST_URL; then
    errors+=("Unable to reach the URL hosting the installation script: $INSTALLATION_TEST_URL.")
fi
set -e
 
end_section
 
################################################ Kernel configuration values  ####################################################
 
 
start_section "Kernel configuration"
 
max_user_instances=$(sysctl fs.inotify.max_user_instances | awk '{print $NF}')
 
if [ "$max_user_instances" -lt 512 ]
then
    errors+=("The kernel configuration fs.inotify.max_user_instances should be set to at least 512 but was detected to be $max_user_instances.")
fi
 
max_io_request=$(sysctl fs.aio-max-nr | awk '{print $NF}')
 
if [ "$max_io_request" -lt 1048576 ]
then
    errors+=("The kernel configuration fs.aio-max-nr should be set to at least 1048576 but was detected to be $max_io_request.")
fi   
 
end_section
 
################################################ Report findings to user ####################################################
 
report_and_exit
