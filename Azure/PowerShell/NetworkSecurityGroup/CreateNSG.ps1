param (
	[Parameter(Mandatory=$True)]
	[string] $servicePrincipalId,
	
	[Parameter(Mandatory=$True)]
	[string] $servicePrincipalPass,
	
	[Parameter(Mandatory=$True)]
	[string] $tenant,
	
	[Parameter(Mandatory=$True)]
	[string] $ResourceGroupName,
	
	[Parameter(Mandatory=$True)]
	[string] $Name,

  [Parameter(Mandatory=$False)]
  [switch] $Overwrite=$False,
	
	[Parameter(ParameterSetName='VirtualNetwork',Mandatory=$False)]
	[string] $VirtualNetworkName,
	
	[Parameter(ParameterSetName='VirtualNetwork',Mandatory=$True)]
  [Parameter(ParameterSetName='NoVirtualNetwork',Mandatory=$False)]
	[string] $VirtualNetworkResourceGroupName,
	
	[Parameter(ParameterSetName='VirtualNetwork',Mandatory=$True)]
  [Parameter(ParameterSetName='NoVirtualNetwork',Mandatory=$False)]
	[string] $SubnetName,
	
	[Parameter(ParameterSetName='VirtualNetwork',Mandatory=$True)]
  [Parameter(ParameterSetName='NoVirtualNetwork',Mandatory=$False)]
	[string] $AddressPrefix
)

#Default vars
$Location = "eastus"

#Stop on error
$ErrorActionPreference = "Stop"

#Login
$password = $servicePrincipalPass | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, $password
Add-AzureRmAccount -Credential $credential -TenantId $tenant -ServicePrincipal

if (-not $Overwrite)
{
	#Search for NSG
	$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $Name -ErrorAction SilentlyContinue
	if ($nsg)
	{
		#Cannot overwrite NSG
		Write-Output "$Name exists in $ResourceGroupName"
		exit 1
	}
}

#Create the NSG
try
{
	$inputstring = @{}
	$inputstring += @{"ResourceGroupName"=$ResourceGroupName}
	$inputstring += @{"Location"=$Location}
	$inputstring += @{"Name"=$Name}
	if ($Overwrite)
	{
		$inputstring += @{"Force"=$True}
	}
	Write-Output "Creating NSG..."
	$nsg = New-AzureRmNetworkSecurityGroup @inputstring
}
catch
{
	Write-Output "NSG $Name could not be created in $ResourceGroupName"
	$Error[0]
	exit 1
}
	
#Set to Virtual Network (if defined)
if ($VirtualNetworkName)
{
	try
	{
		Write-Output "Finding VNET..."
		$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $VirtualNetworkResourceGroupName -Name $VirtualNetworkName
	}
	catch
	{
		Write-Output "Could not find $VirtualNetworkName in $VirtualNetworkResourceGroupName"
		$Error[0]
		exit 1
	}
	try
	{
		Write-Output "Setting NSG on subnet..."
		$nsgvnetset = Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetName -NetworkSecurityGroup $nsg -AddressPrefix $AddressPrefix
	}
	catch
	{
		Write-Output "Could not set $Name on $SubnetName"
		$Error[0]
		exit 1
	}
	try
	{
		Write-Output "Saving NSG on subnet to Azure..."
		Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
	}
	catch
	{
		Write-Output "Could not set $Name on $SubnetName in Azure"
		$Error[0]
		exit 1
	}
}

Write-Output "Complete!"
exit 0
