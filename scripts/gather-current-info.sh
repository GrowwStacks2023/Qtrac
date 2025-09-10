#!/bin/bash

echo "Gathering information about your current Azure infrastructure..."
echo "=============================================================="

echo ""
echo "1. Current Subscription:"
az account show --query '{subscriptionId:id, name:name, tenantId:tenantId}' --output table

echo ""
echo "2. Resource Groups:"
az group list --query '[].{Name:name, Location:location}' --output table

echo ""
echo "3. Virtual Machines:"
az vm list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location, Size:hardwareProfile.vmSize, Status:powerState}' --output table

echo ""
echo "4. Network Security Groups:"
az network nsg list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location}' --output table

echo ""
echo "5. Storage Accounts:"
az storage account list --query '[].{Name:name, ResourceGroup:resourceGroup, Location:location, Tier:sku.tier}' --output table

echo ""
echo "=============================================================="
echo "Please save this information and update the Terraform files accordingly."
