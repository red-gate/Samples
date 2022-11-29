#!/usr/bin/env bash
#############################################################################################################################
# Name        : storage-teardown.sh
# Description : Performs a controlled removal of a rook-ceph controlled cluster (along with all the data). All data images
#               images and data containers will be wiped by this operation.
# Purpose     : This should only be run when there is a ceph storage-related unrecoverable problem in the Kubernetes
#               cluster and it is meant as a faster replacement to having to rebuild the host machine from scratch. 
# Steps       : 1. Run script with '--yes-i-really-really-mean-it' flag.
#               2. Wait for completion
#               3. Redeploy Redgate Clone in KOTS Admin Console.
#               4. Confirm that apllication status becomes 'Ready'.
#               5. (Optional) Use rgclone to delete previous data images and data containers.
#               6. (Optional) Re-add disks if more than 1 was attached.
#############################################################################################################################

######################################################### Globals ###########################################################

CEPH_NAMESPACE="redgate-clone-app"
CONTAINER_NAMESPACE="redgate-clone-data"
DEFAULT_TIMEOUT_SECONDS=120
CEPH_FULL_DISK_REMOVAL_TIMEOUT_SECONDS=86400 # 1 day
FRESH_DELETE=false
SIMPLE_TERMINAL=false

######################################################### Output ############################################################

CHECK_MARK="\033[0;32m\xE2\x9C\x94\033[0m"
CROSS="\033[0;32m\xE2\x9D\x8C\033[0m"
bold=$(tput -T xterm bold)                          # make colors bold/bright
darkblue=$(tput -T xterm setaf 4)                   # dim blue text
blue="$bold$darkblue"                               # bright blue text
dimred="$(tput -T xterm setaf 1)"                   # dim red text
red="$bold$dimred"                                  # bright red text
reset=$(tput -T xterm sgr0)                         # should default to white in most cases

##################################################### Error handling ########################################################

# Exit codes
EXIT_SUCCESS=0
EXIT_FAIL=1
EXIT_CMD_PARSING=2

SIGINT_EXIT_SIGNAL=130  # Script terminated with a CTRL+C SIGINT signal: 128 + SIGINT = 128 + 2 = 130
SIGTERM_EXIT_SIGNAL=143 # Script was terminated with a SIGTERM signal: 128 + SIGTERM = 128 + 15 = 143

# Strict error checking
set -Eeuo pipefail

# Set a global handler trap for any errors occurring in the script's execution (triggered just before termination)
trap 'traperror $?' ERR
traperror() {
  # Special treatment for SIGTERM
  if [ "$1" == "$SIGTERM_EXIT_SIGNAL" ]; then
    echo "${red}Script asked to terminate (SIGTERM) by external party (e.g. kill, pkill) on line '$(caller)' in command '${BASH_COMMAND}'!" >&2
  elif [ "$1" != "$SIGINT_EXIT_SIGNAL" ]; then
    echo
    local executedcommand=${BASH_COMMAND}
    echo "${red}Script failed with error '$1' on line '$(caller)' in command '${executedcommand}'!${reset}" >&2
  fi
}

# Trap to ensure we print an error message as soon as we try to exit the script with a non-zero (i.e. error) exit code
trap 'trapexit $?' EXIT
trapexit() {
  if [ "$1" != "$EXIT_SUCCESS" ]; then
    echo >&2
    echo "${red}Script was terminated abnormally and exited with error '$1'!${reset}" >&2
  fi
}

######################################################### Output ############################################################

function __clearlastline() {
  [[ $SIMPLE_TERMINAL == "false" ]] && tput cuu 1 && tput el
}

function successoverwrite() {
  __clearlastline
  success "$*"
}

function success() {
  echo -e "      $CHECK_MARK $*"
}

function erroroverwrite() {
  __clearlastline
  error "$*"
 
}

function error() {
   echo -e "      $CROSS $*"
}

function outputtextoverwrite() {
  __clearlastline
  outputtext "$*"
}

function outputtext() {
  echo "      $*"
}

function rederror() {
  echo "${red}$*${reset}"
}

##################################################### Argument Parsing ######################################################

function parsecommandline() {
    echo "Checking command line:"

    # Set defaults for command line parameters
    FULL_DISK_CLEANUP=false
    FOR_REAL=false

    printusage() {
      echo "
Usage:
    -f / --full-disk-cleanup        Sanitize the entire disk(s) instead of only the default's ceph's metadata. This is much slower.
    --yes-i-really-really-mean-it   Confirmation parameter required to actually carry out the destructive operation.
"
    }

    printusageandexit() {
        success "Script help requested."
        printusage
        exit $EXIT_SUCCESS
    }

    printusagewitherror() {
        printusage
        error "Please review command line arguments and try again."
        exit $EXIT_CMD_PARSING
    }

    die() {
        echo "$*" >&2
        printusagewitherror
    } # Complain to STDERR and exit with error

    # When using getopts inside a function call (like in here), make sure to set OPTIND as local or the function will not be
    # idempotent (i.e. the shell does not reset it between multiple calls to getopts)
    local OPTIND OPT
    while getopts "fyh-:" OPT; do
        if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
            OPT="${OPTARG%%=*}"     # extract long option name
            OPTARG="${OPTARG#$OPT}" # extract long option argument (may be empty)
            OPTARG="${OPTARG#=}"    # if long option argument, remove assigning `=`
        fi

        case "$OPT" in
        f | full-disk-cleanup)    FULL_DISK_CLEANUP=true ;;
        y | yes-i-really-really-mean-it)
          if [[ $OPT != "y" ]]; then
            FOR_REAL=true
          else
            printusagewitherror
          fi
          ;;
        h | help)                 printusageandexit ;;
        ??*)                      die "$BASH_SOURCE: illegal option -- $OPT" ;; # bad long option (mirroring getopts format)
        ?)                        printusagewitherror ;;                        # bad short option (error reported via getopts)
        esac
    done

    # Remove parsed options and args from $@ list
    shift $((OPTIND - 1))

    if ! $FOR_REAL; then
      error "Missing required command line parameter for actual data storage removal."
      echo
      rederror "Caution: This script will remove ALL your existing data (including data containers and data images)."
      rederror "Use flag ${blue}--yes-i-really-really-mean-it${red} if you definitely want to proceed!"
      echo
      exit $EXIT_SUCCESS
    fi

    $FULL_DISK_CLEANUP && DISK_CLEANUP_TYPE="${blue}FULL${reset}" || DISK_CLEANUP_TYPE="${blue}QUICK${reset}"
    success "Disk cleanup mode: ${DISK_CLEANUP_TYPE}."
    success "Command line OK."
    echo
}

######################################################## Checkers ###########################################################

# Gets the full k8s resource name matching the given (partial) name. Returns empty if not found.
function findresourcenamebyprefix() {
  local namespace=$1
  local type=$2
  local nameprefix=$3

  local resourcename=$(kubectl get -n $namespace $type -o json | jq -j '.items[].metadata.name | select(. | startswith("'$nameprefix'"))')
  echo $resourcename
}

# Checks whether the given k8s resource exists (true) or not (false).
function resourceexists() {
  local namespace=$1
  local type=$2
  local name=$3 # Needs to be an exact match

  local resource=$(kubectl get -n $namespace $type $name --ignore-not-found)
  [[ ! -z $resource ]] && echo true || echo false
}

# Force a y/Y user confirmation before continuing the script's execution
function asktocontinue() {
    local actionmessage=${1:-}  # Anything we want to ask the user to do prior to continuing
    local successmessage=${2:-} # What to show if user decides to continue
    local abortmessage=${3:-}   # What to show if user decides to abort

    if [[ ! -z  "$actionmessage" ]]; then
      actionmessage="$actionmessage "
    fi
    if [[ -z  "$successmessage" ]]; then
      successmessage="OK."
    fi
    if [[ -z  "$abortmessage" ]]; then
      abortmessage=" "
    else
      abortmessage="$abortmessage "
    fi

    # We ask for a one key confirmation (-n 1): anything other than 'y/n' will cause a repetition of the question.
    # NOTE: We accept backslashes literally (-r) or our 'read' call would see the backslash as the beginning of an escape
    #       sequence and wait for a second character to come through.
    while  read -p "      ${actionmessage}Continue [y/n]? " -n 1 -r; do
      echo
      [[ $REPLY =~ ^[Yy]$ ]] && successoverwrite $successmessage && return $EXIT_SUCCESS
      [[ $REPLY =~ ^[Nn]$ ]] && erroroverwrite "${abortmessage}Aborting script..." && return $EXIT_FAIL
    done
}

####################################################### Deleters ############################################################

# Get rid of any finalizers present in the given resource in preparation for resource removal.
function removefinalizersifpresent() {
  local namespace=$1
  local type=$2
  local name=$3 # Needs to be an exact match

  if $(resourceexists $namespace $type $name); then
    outputtext "$namespace: $type/$name removing finalizers...";
    kubectl patch -n "$namespace" $type $name --type merge -p '{"metadata":{"finalizers":null}}' 2>&1 > /dev/null
    successoverwrite "$namespace: $type/$name finalizers removed."
  fi
}

# Destroys a k8s resource in the cluster. Attempts it gracefully first and then force deletes if something goes wrong.
function deleteresource {
  local namespace=$1
  local type=$2
  local name=$3 # Needs to be an exact match

  outputtext "$namespace: $type/$name deleting..."

  # Graceful deletetion first
  if $(resourceexists $namespace $type $name); then
    # NOTE: PVCs have namespaces, but PVs don't
    # NOTE2: We want to suppress stdout here as 'kubectl delete' is chatty (but still keep stderr)
    if [[ $type == "pv" || $type == "storageclass" ]]; then
      kubectl delete $type $name 2>&1 > /dev/null
    else
      kubectl delete -n "$namespace" $type $name 2>&1 > /dev/null
    fi
    successoverwrite "$namespace: $type/$name deleted."
    
    if [[ $name == "ceph-cluster" ]]; then
      FRESH_DELETE=true
    fi

    # NOTE: We prevent script termination if we hit the timeout, so we can attempt a force kill afterwards
    __waittoterminate $namespace $type $name false
  else 
    successoverwrite "$namespace: $type/$name is already deleted."
  fi

  # Force deletion if resource is still present
  if $(resourceexists $namespace $type $name); then
    outputtext "$namespace: $type/$name force deleting..."
    # NOTE: PVCs have namespaces, but PVs don't
    # NOTE2: We want to suppress stdout here as 'kubectl delete' is chatty (but still keep stderr)
    if [[ $type == "pv" || $type == "storageclass" ]]; then
      kubectl delete $type $name --force 2>&1 > /dev/null
    else
      kubectl delete -n "$namespace" $type $name --force 2>&1 > /dev/null
    fi
    successoverwrite "$namespace: $type/$name force deleted."

    if [[ $name == "ceph-cluster" ]]; then
      FRESH_DELETE=true
    fi

    # NOTE: Unlike for the graceful deletion above, we want to cause a script termination if we hit the timeout
    __waittoterminate $namespace $type $name
  fi

  # Resource should be gone by now
  # NOTE: Fail-safe as a timeout should have been hit above
  if $(resourceexists $namespace $type $name); then
    erroroverwrite "$namespace: $type/$name still exists when it should have been (force) terminated. Terminating script..."
    exit $EXIT_FAIL
  fi
}

# Destroy all the Persistent Volumes (PVs) or Persistent Volume Claims (PVCs) for the given storage class 
function deletepersistentvolumesorclaimsbystorageclassname() {
  local namespace=$1
  local type=$2
  local storageclassname=$3
  local removefinalizers=${4:-false}

  local list=$(kubectl get -n $namespace $type -o json --ignore-not-found | jq '.items[] | select(.spec.storageClassName=="'$storageclassname'") | .metadata.name')
  while IFS= read -r resourcenametodelete; do
    resourcenametodelete=$(echo "$resourcenametodelete" | tr -d '"')
    if [[ ! -z $resourcenametodelete ]]; then
      $removefinalizers && removefinalizersifpresent $namespace $type $resourcenametodelete
      deleteresource $namespace $type $resourcenametodelete
    fi
  done <<< "$list"
}

# Remove the existing database server instances CRDs (used by both data images and data containers).
function deletealldatabaseserverinstances() {
  local removefinalizers=${1}

  local list=$(kubectl get -n redgate-clone-data databaseserverinstance -o json --ignore-not-found | jq '.items[] | .metadata.name')
  while IFS= read -r resourcenametodelete; do
    resourcenametodelete=$(echo "$resourcenametodelete" | tr -d '"')
    if [[ ! -z $resourcenametodelete ]]; then
      $removefinalizers && removefinalizersifpresent "redgate-clone-data" "databaseserverinstance" $resourcenametodelete
      deleteresource "redgate-clone-data" "databaseserverinstance" $resourcenametodelete
    fi
  done <<< "$list"

  # Kill any pods
  local resourcesfound=$(kubectl get -n redgate-clone-data pods --no-headers -o custom-columns=":metadata.name" | grep "database-server-instance" || :)
  if [[ ! -z "$resourcesfound" ]]; then
    while IFS= read -r resourcenametodelete; do
        deleteresource "redgate-clone-data" "pod" $resourcenametodelete
    done <<< "$resourcesfound"
  fi
}

# Destroys the cleanup job used by Rook to clean up the Ceph cluster
function deletecephcleanupjob() {
  # NOTE: A suffix based on the host machine's name will be automatically added by Ceph to the job's name
  fulljobname=$(findresourcenamebyprefix $CEPH_NAMESPACE "job" "cluster-cleanup-job")
  if [[ ! -z $fulljobname ]]; then
    deleteresource $CEPH_NAMESPACE "job" $fulljobname
  fi
}

######################################################## Waiters ############################################################

# Loops and polls the given k8s resource until it is found or a timeout is hit
function __waittoterminate() {
  local namespace=$1
  local type=$2
  local name=$3 # Needs to be an exact match
  local terminate=${4:-true}

  local counterinseconds=0
  until [[ $(resourceexists "$namespace" "$type" "$name") == false ]]; do
    [[ $counterinseconds == 0 ]] && echo
    ((++counterinseconds))
    if [[ ${counterinseconds:-0} -ge $DEFAULT_TIMEOUT_SECONDS ]]; then 
      $terminate && erroroverwrite "$namespace: $type/$name reached ${DEFAULT_TIMEOUT_SECONDS}s timeout while waiting for termination. This is unexpected. Terminating script..." && exit $EXIT_FAIL
      erroroverwrite "$namespace: $type/$name reached ${DEFAULT_TIMEOUT_SECONDS}s timeout while waiting for termination. Ignoring."
      break
    else
      sleep 1
      outputtextoverwrite "$namespace: $type/$name waiting to terminate... $counterinseconds/${DEFAULT_TIMEOUT_SECONDS}s"
    fi
  done

  if [[ $counterinseconds != 0 && $counterinseconds -lt $DEFAULT_TIMEOUT_SECONDS ]]; then 
    successoverwrite "$namespace: $type/$name terminated."
  fi
}

# Waits for the ceph job that gets triggered by the deletion policy that we've added and that is reponsible for 
# gracefully terminating the ceph cluster and associated dependencies (e.g. storage)
function waitforcephjobcompletion() {
  local namespace=$1
  local type=$2
  local labelselector=$3

  if $FRESH_DELETE; then
    # Wait for the k8s data storage job resource to appear
    # NOTE: This typically takes a few seconds
    outputtext "$namespace: $type/$labelselector waiting for storage data deletion job to initialize..."
    local counterinseconds=0
    while [[ -z $(kubectl get -n $namespace $type --selector="$labelselector" --no-headers -o custom-columns=":metadata.name" || :) ]]; do
      ((++counterinseconds))
      if [[ ${counterinseconds:-0} -ge $DEFAULT_TIMEOUT_SECONDS ]]; then
        erroroverwrite "$namespace: $type/$labelselector reached ${DEFAULT_TIMEOUT_SECONDS}s timeout while waiting for storage data deletion job to init. This is unexpected. Terminating script..."
        exit $EXIT_FAIL
      else
        sleep 1
        outputtextoverwrite "$namespace: $type/$labelselector waiting for data deletion job to initialize... $counterinseconds/${DEFAULT_TIMEOUT_SECONDS}s"
      fi
    done
    successoverwrite "$namespace: $type/$labelselector storage data job initialised."

    # Determine timeout to use based on type of Ceph cluster disk cleanup
    $FULL_DISK_CLEANUP && local jobtimeout=$CEPH_FULL_DISK_REMOVAL_TIMEOUT_SECONDS || local jobtimeout=$DEFAULT_TIMEOUT_SECONDS

    # NOTE: Kubernetes instances are loosely coupled by the means of labels (key-value pairs), hence we need to search for 
    #       labels using a selector instead of partial names as 'kubectl wait' expects exact name matches (and our ceph
    #       removal job will have an rook added suffix to its name)
    # NOTE2: 'kubectl wait' has no awareness of new resources that get created AFTER it gets triggered, so it's advisable for the
    #        caller to ensure the resources being waited for are already created at this point (as we do above) or this 
    #        could block indefinitely (or until it hits the timeout)
    outputtext "$namespace: $type/$labelselector cleaning up storage data (this may take a while, timeout=${jobtimeout}s)..."
    kubectl wait -n $namespace "job" --selector=$labelselector --for=condition=complete --timeout="${jobtimeout}s" 2>&1 > /dev/null
    successoverwrite "$namespace: $type/$labelselector job completed."
  fi
}

# Finds all kubernetes resources of the given type, which match the provided (partial) name
function waittoterminatebypartialnamelookup() {
  local namespace=$1
  local type=$2
  local namelookup=$3 # This can be a partial match

  local resourcesFound=$(kubectl get -n $namespace $type --no-headers -o custom-columns=":metadata.name" | grep $namelookup || :)

  if [[ ! -z "$resourcesFound" ]]; then
    while IFS= read -r resourcenametodelete; do
        __waittoterminate $namespace $type $resourcenametodelete
    done <<< "$resourcesFound"
  else
    echo
    successoverwrite "$namespace: $type/$namelookup is already removed/completed."
  fi
}

########################################################### Main ############################################################

parsecommandline "$@"

echo "Verifying needed dependencies:"
outputtext "Checking if jq is installed..."
if ! [ -x "$(command -v jq)" ]; then
  erroroverwrite "jq is needed. Please follow guide at https://stedolan.github.io/jq/download/. On Ubuntu, you should be able to install it via 'sudo apt-get install jq'."
  exit $EXIT_FAIL
fi
successoverwrite "jq successfully found in system."
echo

# We need to make sure we don't have anything from past cleanup still hanging around (e.g. if script was interrupted with 
# Ctrl+C or failed early)
echo "Pre-setup checks:"
deletecephcleanupjob
if $FULL_DISK_CLEANUP; then
  asktocontinue "Full disk cleanup is a slow process (can be a few hours depending on the size of your storage) and should only be used if the default quick one failed." "Full disk cleanup mode accepted." "Full disk cleanup mode not accepted."
fi
success "Ready to go."
echo

# Clean-up all resources related to data images and containers inside cluster
echo "Starting cleanup of the data storage used by existing data images and data containers:"
deletealldatabaseserverinstances true
deletepersistentvolumesorclaimsbystorageclassname $CONTAINER_NAMESPACE "pvc" "rook-ceph-block" true
deletepersistentvolumesorclaimsbystorageclassname $CONTAINER_NAMESPACE "pv" "rook-ceph-block" true
success "Data storage used by data images and data container cleaned-up (metadata NOT removed from configuration database)."
echo

# Now for the rest of the storage. Start removing Ceph CRDs
echo "Starting cleanup of the in-cluster data storage provider:"
removefinalizersifpresent $CEPH_NAMESPACE "cephblockpool" "ceph-block-pool"
deleteresource $CEPH_NAMESPACE "cephblockpool" "ceph-block-pool"
removefinalizersifpresent $CEPH_NAMESPACE "cephblockpool" "builtin-mgr"
deleteresource $CEPH_NAMESPACE "cephblockpool" "builtin-mgr"
deleteresource $CEPH_NAMESPACE "storageclass" "rook-ceph-block"
deleteresource $CEPH_NAMESPACE "storageclass" "local-storage"

# Set Ceph cleanup based on user's input (default: quick)
quickcleanuppolicy='{"spec":{"cleanupPolicy":{"confirmation": "yes-really-destroy-data", "sanitizeDisks":{"method": "quick", "dataSource": "zero", "iteration": 1}}}}'
fullcleanuppolicy='{"spec":{"cleanupPolicy":{"confirmation": "yes-really-destroy-data", "sanitizeDisks":{"method": "complete", "dataSource": "random", "iteration": 1}}}}'
$FULL_DISK_CLEANUP && cleanuppolicytouse="$fullcleanuppolicy" || cleanuppolicytouse="$quickcleanuppolicy"

# Patch Ceph's cluster to have an explicit cleanup policy
# NOTE: By default, only the ceph's metadata will be cleared (quick method) and zero bytes will be used for the operation.
#       If full disk cleanup is provided, the whole disk(s) will be sanitized (complete method) and random bytes will be
#       used for the operation. This is much slower and should only really be needed if the quick method did not lead
#       to a successful redeployment of Redgate Clone.
if $(resourceexists $CEPH_NAMESPACE "cephcluster" "ceph-cluster"); then
  outputtext "$CEPH_NAMESPACE: cephcluster/ceph-cluster updating cleanup policy..."
  kubectl patch -n $CEPH_NAMESPACE cephcluster ceph-cluster --type merge -p "$cleanuppolicytouse" 2>&1 > /dev/null
  successoverwrite "$CEPH_NAMESPACE: cephcluster/ceph-cluster cleanup policy updated."
fi

# Delete Ceph's cluster
# NOTE: The above cleanup policy will cause the removal of the rook-ceph manager and monitor (but not the operator
#       nor the ceph tools) and most importantly will trigger a cleanup job 'cluster-cleanup-job-*' to: 
#         - Remove all the rook-ceph data in the dataDirHostPath (/var/lib/rook).
#         - Wipe the data on the drives on all the nodes where OSDs were running in this cluster (including removing the 
#           ceph_bluestore file system). This will either be with the quick or complete methods (see above).
deleteresource $CEPH_NAMESPACE "cephcluster" "ceph-cluster"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "rook-ceph-mgr"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "rook-ceph-mon"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "rook-ceph-osd"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "csi-rbdplugin"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "csi-rbdplugin-provisioner"

# A data storage removal job should kick-off and start cleaning the data in the cluster
waitforcephjobcompletion $CEPH_NAMESPACE "job" "rook-ceph-cleanup=true"

# Now delete the remaining Ceph utilities that are not affected by the cleanup policy
deleteresource $CEPH_NAMESPACE "deployment" "rook-ceph-operator"
deleteresource $CEPH_NAMESPACE "deployment" "rook-ceph-tools"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "rook-ceph-operator"
waittoterminatebypartialnamelookup $CEPH_NAMESPACE "pod" "rook-ceph-tools" # This one can take a few seconds

# And don't forget the local storage as well
deletepersistentvolumesorclaimsbystorageclassname $CEPH_NAMESPACE "pvc" "local-storage"
deletepersistentvolumesorclaimsbystorageclassname $CEPH_NAMESPACE "pv" "local-storage"

# Delete local provisioner daemonset
deleteresource "kube-system" "daemonset" "local-volume-provisioner"

# Finally, cleanup Ceph job
deletecephcleanupjob

# Echo to redeploy (i.e. to get a fresh storage in place)
echo
success "The cluster data storage has been cleaned-up."
echo
echo "   Follow up tasks:"
echo "      1. Go to KOTS Admin Console dashboard and:"
echo "          - (if doing an upgrade) Press 'Check for update' and 'Deploy' the new version with a fresh empty storage."
echo "          - (otherwise)           Hit 'Redeploy' to restore the current version with a new clean storage"
echo
echo "      2. Wait for the Application status to become Ready in the KOTS Admin Console UI."
echo
echo "      3. (Optional, but recommended) Clean-up previous data images and data containers using 'rgclone':"
echo "          - Run './rgclone get all' to get the old IDs of data images and data containers"
echo "          - Delete resources manually (i.e. './rgclone delete dc 14 15 16' (these are example IDs))"
echo
echo "      4. (If needed) Re-add disks if you have multiple ones setup (see below)."
echo
echo "   Note:"
echo "      If you had more than 1 disk attached, you will have to re-add them to the cluster."
echo "      This action can only be done after the application is fully ready (step 2 above)"
echo "      To add disks to the cluster, follow the instructions here: https://documentation.red-gate.com/x/rIDuC"
