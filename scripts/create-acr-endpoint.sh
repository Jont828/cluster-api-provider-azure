#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# TODO: check for az cli to be installed in local
# wait for AKS VNet to be in the state created

REPO_ROOT=$(dirname "${BASH_SOURCE[0]}")/..
# shellcheck source=hack/common-vars.sh
source "${REPO_ROOT}/hack/common-vars.sh"

source "${REPO_ROOT}/aks-mgmt-vars.env"

export DNS_SUBNET_NAME="dns-subnet"
export DNS_SUBNET_CIDR="10.0.2.0/24"
export REGISTRY_ID=$(az acr show --name $REGISTRY --query 'id' --output tsv) # Only for ACR
export REGISTRY_NAME="${REGISTRY%%.*}"

echo "-------- Creating Private Endpoint and Link to Azure Container Registry  --------"

# wait for workload VNet to be created
az network vnet wait --resource-group ${CLUSTER_NAME} --name ${CLUSTER_NAME}-vnet --created --timeout 180
export WORKLOAD_VNET_ID=$(az network vnet show --resource-group ${CLUSTER_NAME} --name ${CLUSTER_NAME}-vnet --query id --output tsv)
echo " 1/7 ${CLUSTER_NAME}-vnet found with ID: ${WORKLOAD_VNET_ID} "

# create dns subnet
# TODO: check if exists before attempting to create
az network vnet subnet create -g ${CLUSTER_NAME} --vnet-name ${CLUSTER_NAME}-vnet -n ${DNS_SUBNET_NAME} --address-prefixes ${DNS_SUBNET_CIDR}  --disable-private-endpoint-network-policies
az network vnet subnet wait --name ${DNS_SUBNET_NAME} --resource-group ${CLUSTER_NAME} --vnet-name ${CLUSTER_NAME}-vnet --created --timeout 300 --only-show-errors --output none
echo " 2/7 subnet ${DNS_SUBNET_NAME} created in ${CLUSTER_NAME}-vnet"

# create private dns zone
# TODO: check if exists before attempting to create
az network private-dns zone create --resource-group ${CLUSTER_NAME} --name "privatelink.azurecr.io" --only-show-errors --output none
az network private-dns zone wait --resource-group ${CLUSTER_NAME} --name "privatelink.azurecr.io" --created --timeout 300 --only-show-errors --output none
echo " 3/7 privatelink.azurecr.io private DNS zone created in ${CLUSTER_NAME}"

# link private DNS Zone to vnet
# TODO: check if exists before attempting to create
az network private-dns link vnet create --resource-group ${CLUSTER_NAME} --zone-name "privatelink.azurecr.io" --name dns-to-${CLUSTER_NAME} --virtual-network ${WORKLOAD_VNET_ID} --registration-enabled false --only-show-errors --output none
az network private-dns link vnet wait --resource-group ${CLUSTER_NAME} --zone-name "privatelink.azurecr.io" --name dns-to-${CLUSTER_NAME} --created --timeout 300 --only-show-errors --output none
echo " 4/7 workload cluster vnet ${CLUSTER_NAME}-vnet linked with private DNS zone 'privatelink.azurecr.io'"

az network private-endpoint create --name myPrivateEndpoint --resource-group ${CLUSTER_NAME} --vnet-name ${CLUSTER_NAME}-vnet --subnet ${DNS_SUBNET_NAME} --private-connection-resource-id $REGISTRY_ID --group-ids registry --connection-name myConnection --only-show-errors --output none
az network private-endpoint wait --name myPrivateEndpoint --resource-group ${CLUSTER_NAME} --created --timeout 300 --only-show-errors --output none
echo " 5/7 private endpoint created for Azure Container Registry"

# Get variables for DNS record creation
NETWORK_INTERFACE_ID=$(az network private-endpoint show --name myPrivateEndpoint --resource-group ${CLUSTER_NAME} --query 'networkInterfaces[0].id' --output tsv)
REGISTRY_PRIVATE_IP=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateIPAddress" --output tsv)
DATA_ENDPOINT_PRIVATE_IP=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$AZURE_LOCATION'].privateIPAddress" --output tsv)
# An FQDN is associated with each IP address in the IP configurations
REGISTRY_FQDN=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry'].privateLinkConnectionProperties.fqdns" --output tsv)
DATA_ENDPOINT_FQDN=$(az network nic show --ids $NETWORK_INTERFACE_ID --query "ipConfigurations[?privateLinkConnectionProperties.requiredMemberName=='registry_data_$AZURE_LOCATION'].privateLinkConnectionProperties.fqdns" --output tsv)
echo " 6/7 fetched private endpoint IPs and FQDNs"

# Create DNS records
az network private-dns record-set a create --name $REGISTRY_NAME --zone-name privatelink.azurecr.io --resource-group ${CLUSTER_NAME} --only-show-errors --output none
# Specify registry region in data endpoint name
az network private-dns record-set a create --name ${REGISTRY_NAME}.${AZURE_LOCATION}.data --zone-name privatelink.azurecr.io --resource-group ${CLUSTER_NAME} --only-show-errors --output none
az network private-dns record-set a add-record --record-set-name $REGISTRY_NAME --zone-name privatelink.azurecr.io --resource-group ${CLUSTER_NAME} --ipv4-address $REGISTRY_PRIVATE_IP --only-show-errors --output none
# Specify registry region in data endpoint name
az network private-dns record-set a add-record --record-set-name ${REGISTRY_NAME}.${AZURE_LOCATION}.data --zone-name privatelink.azurecr.io --resource-group ${CLUSTER_NAME} --ipv4-address $DATA_ENDPOINT_PRIVATE_IP --only-show-errors --output none
echo " 7/7 DNS records created for Azure Container Registry"
