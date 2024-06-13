#!/usr/bin/env bash

logger "Redgate Clone graceful shutdown."
# This script can be used to gracefully drain a redgate clone node. This is useful for a reboot or a shutdown.

set -Eeuo pipefail

currentmachine=$(cat /etc/machine-id)
command="kubectl get nodes -o=jsonpath='{.items[?(@.status.nodeInfo.machineID==\"$currentmachine\")].metadata.name}'"

currentnode=$($command)
currentnode=$(echo "|$currentnode|" | cut -d "'" -f 2)

echo "Cordon node $currentnode on machine $currentmachine"
kubectl cordon $currentnode

echo "Drain $currentnode on machine $currentmachine"
kubectl drain $currentnode --ignore-daemonsets --delete-emptydir-data --skip-wait-for-delete-timeout=60

logger "Redgate Clone graceful shutdown completed."
