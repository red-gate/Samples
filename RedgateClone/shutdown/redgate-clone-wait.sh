#!/usr/bin/env bash

# This script can be used to uncordon a node on the redgate cluster. This is useful after a reboot or shutdown.

set -Eeuo pipefail

currentmachine=$(cat /etc/machine-id)
command="kubectl get nodes -o=jsonpath='{.items[?(@.status.nodeInfo.machineID==\"$currentmachine\")].metadata.name}'"

currentnode=$($command)
currentnode=$(echo "|$currentnode|" | cut -d "'" -f 2)

echo "Unordon node $currentnode on machine $currentmachine"
kubectl uncordon $currentnode

sudo /bin/systemctl enable redgate-clone-shutdown.service
sudo /bin/systemctl start redgate-clone-shutdown.service

logger "Redgate Clone started waiting for shutdown."