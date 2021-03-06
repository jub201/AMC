# TITLE: New Research Workbench Deploy
# DETAILS: Deploy a mixed IaaS/PaaS Research environment secured to allow for on-prem to Azure but not Internet to Azure research computing
# AUTHOR: Joey Brakefield
# TODO: Add Keyvault, parameterize VM names, invoke from BASH to PoSH and PoSH to BASH

#$rwbname = $args[0]
$rwbname = "mhd"
$location = "eastus"
#$location = $args[1]
#$mgmtvnet = $args[2]
$rwbvnetname = "$rwbname-vnet"
$rwbrg = "$rwbname-rg"
$rwbmgmtrg = "$rwbname"+ "mgmt-rg"

# For Execution in Azure Cloud Shell
#cd $file

# Deploy the foundational VNET for IaaS Workloads
New-AzResourceGroup -name $rwbrg -Location $location -Force
$vnetparams = @{
    vnetName = $rwbvnetname
}
Write-Host "ok if this errors..."
# Check to see if IaaS vNet Exists

$rwbvnet = Get-AzVirtualNetwork -ResourceGroupName $rwbrg -Name $vnetparams.vnetName
New-AzResourceGroup -name $rwbmgmtrg -Location $location -Force

# VNET creation for Mgmt and IaaS boxes in RWB
if($rwbvnet -eq $null){
    Write-Host $vnetname " doesn't Exist, creating..."


    $rwbvnet = New-AzVirtualNetwork -Name $rwbvnetname -ResourceGroupName $rwbmgmtrg -Location $location -AddressPrefix 10.5.0.0/16 

    $subnet1Name = "AzureBastionSubnet"
    $subnet1 = Add-AzVirtualNetworkSubnetConfig -Name $subnet1Name -AddressPrefix 10.5.0.0/24 -VirtualNetwork $rwbvnet
    $subnet2Name = "IaaSSubnet"
    $subnet2 = Add-AzVirtualNetworkSubnetConfig -Name $subnet2Name -AddressPrefix 10.5.1.0/24 -VirtualNetwork $rwbvnet
    $rwbvnet | Set-AzVirtualNetwork


   # $vnetdeploy = New-AzResourceGroupDeployment -TemplateParameterObject $vnetparams -TemplateFile "$HOME\AMC\amc-rwb\0-foundation\rwbvnet.template.json" -ResourceGroupName $rwbrg
   # $vnetdeploy
} else {
    Write-Host $rwbvnet.name"network already exists"
}



# Deploy Resource Group for VNET and Bastion Host
New-AzResourceGroup -name $rwbmgmtrg -Location $location -Force
# Deploy the Bastion Host for Secured VNET access to all your IaaS resources
$bastionPIP = New-AzPublicIpAddress -ResourceGroupName $rwbmgmtrg -name $rwbname"-bastion-pip" -location $location -AllocationMethod Static -Sku Standard
# ISSUE WITH AZURE POLICY --> CAN'T BIND THE PIP TO THE AZ BASTION INSTANCE EVEN THOUGH WE HAVE PERMISSIONS TO CREATE BASTION ITSELF
$bastion = New-AzBastion -ResourceGroupName $rwbmgmtrg -Name $rwbname"-bastion" -PublicIpAddress $bastionPIP -VirtualNetwork $rwbvnet

<# Old Bastion Deploy
$bastionparams = @{
    location = $location
    "vnet-name" = $mgmtvnet.name
    "vnet-ip-prefix" = "10.175.0.0/21"
    "vnet-new-or-existing" = "existing"
    "bastion-subnet-ip-prefix" = "10.175.1.0/27"
    "bastion-host-name" = "$rwbname-bastion"

}
New-AzResourceGroupDeployment -TemplateFile "$HOME\AMC\amc-rwb\1-azbastionbroker\bastiondeploy.json" -ResourceGroupName $rwbmgmtrg -TemplateParameterObject $bastionparams -location $location 
#>




# Now Let's Deploy the Workbench Resources
New-AzResourceGroup -name $rwbrg -Location $location -Force

# First let's deploy a secure Ubuntu Data Science VM
## Let's replace the VNET ID with the one you deployed above
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rwbmgmtrg -Name "$rwbname-vnet"
$udsvmpfilepath = "$HOME\AMC\amc-rwb\2-dsvm-ubuntu\udsvm.parameters.json"
$udsvmparams = Get-Content -Path $udsvmpfilepath -Raw | ConvertFrom-Json
$udsvmparams.parameters.virtualNetworkId = @{value=$vnet.id}  

# NEED TO FIND THE CORRECT NAMING, ADD TO THE ABOVE PARAMS
$udsvmparams | ConvertTo-Json -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content -Path $HOME"\AMC\amc-rwb\custom-udsvm.parameters.json"


## Now deploy the Ubuntu DSVM to Azure
New-AzResourceGroupDeployment -TemplateFile "$HOME\AMC\amc-rwb\2-dsvm-ubuntu\udsvm.template.json" -ResourceGroupName $rwbrg -TemplateParameterFile $HOME"\AMC\amc-rwb\custom-udsvm.parameters.json" -location $location 

## Deploy a Windows DSVM to Azure
## Let's replace the VNET ID with the one you deployed above
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rwbmgmtrg -Name "$rwbname-vnet"
$wdsvmpfilepath = "$HOME\AMC\amc-rwb\4-dsvm-win\wdsvm.parameters.json"
$wdsvmparams = Get-Content -Path $wdsvmpfilepath -Raw | ConvertFrom-Json
$wdsvmparams.parameters.virtualNetworkId = @{value=$vnet.id}  
$wdsvmparams | ConvertTo-Json -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content -Path $HOME"\AMC\amc-rwb\custom-wdsvm.parameters.json"

## Now deploy the Ubuntu DSVM to Azure
New-AzResourceGroupDeployment -TemplateFile "$HOME\AMC\amc-rwb\4-dsvm-win\wdsvm.template.json" -ResourceGroupName $rwbrg -TemplateParameterFile $HOME"\AMC\amc-rwb\custom-wdsvm.parameters.json" -location $location 
