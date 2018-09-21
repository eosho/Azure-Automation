param (
	[Parameter(Mandatory=$True)]
	[string] $servicePrincipalId,
	
	[Parameter(Mandatory=$True)]
	[string] $servicePrincipalPass,
	
	[Parameter(Mandatory=$True)]
	[string] $tenant,
	
	[Parameter(Mandatory=$True)]
	[string] $NetworkSecurityGroupName,
	
	[Parameter(Mandatory=$True)]
	[string] $ResourceGroupName,
	
	[Parameter(Mandatory=$False)]
	[switch] $Overwrite=$False,
	
	[Parameter(Mandatory=$True)]
	[string] $RuleName,
	
	[Parameter(Mandatory=$False)]
	[string] $Description,
	
	[Parameter(Mandatory=$True)]
	[ValidateSet('Allow','Deny')]
	[string] $Access,
	
	[Parameter(Mandatory=$True)]
	[ValidateSet('Tcp','Udp','*')]
	[string] $Protocol,
	
	[Parameter(Mandatory=$True)]
	[ValidateSet('Inbound','Outbound')]
	[string] $Direction,
	
	[Parameter(Mandatory=$True)]
	[ValidateRange(100,4096)]
	[int] $Priority,
	
	[Parameter(Mandatory=$True)]
	[string] $SourceAddressPrefix,
	
	[Parameter(Mandatory=$True)]
	$SourcePortRange,
	
	[Parameter(Mandatory=$True)]
	[string] $DestinationAddressPrefix,
	
	[Parameter(Mandatory=$True)]
	$DestinationPortRange
)

#Default vars
$Location = "eastus"

#Stop on error
$ErrorActionPreference = "Stop"

#Login
$password = $servicePrincipalPass | ConvertTo-SecureString -AsPlainText -Force
$credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipalId, $password
Add-AzureRmAccount -Credential $credential -TenantId $tenant -ServicePrincipal

#Retrieve the NSG
try
{
	Write-Output "Finding NSG..."
	$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $NetworkSecurityGroupName
}
catch
{
	Write-Output "Cannot find $NetworkSecurityGroupName in $ResourceGroupName"
	$Error[0]
	exit 1
}

#Convert ports to list
$SourcePortRange = $SourcePortRange.Split(',')
$DestinationPortRange = $DestinationPortRange.Split(',')

$inputstring = @{}
$inputstring += @{"NetworkSecurityGroup"=$nsg;"Name"=$RuleName}
foreach ($VariableName in @("Description","Access","Protocol","Direction","Priority","SourceAddressPrefix","SourcePortRange","DestinationAddressPrefix","DestinationPortRange"))
{
	if ((Get-Variable -Name $VariableName -ErrorAction SilentlyContinue).Value.Length -gt 0)
	{
		$inputstring += @{$VariableName=(Get-Variable -Name $VariableName).Value}
	}
}
$inputstring

if ($Overwrite)
{
	Write-Output "Setting nsg rules..."
	$nsgset = Set-AzureRmNetworkSecurityRuleConfig @inputstring
}
else
{
	#Search for rule
	if ($nsg.SecurityRules.Name -contains $RuleName) {
		Write-Output "Rule $RuleName already exists in $NetworkSecurityGroupName"
		exit 1
	}

	#Add the rule
	Write-Output "Adding nsg rules..."
	$nsgadd = Add-AzureRmNetworkSecurityRuleConfig @inputstring
}

#Save to azure
try
{
	Write-Output "Saving to Azure..."
	Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg
}
catch
{
	Write-Output "Could not write $NetworkSecurityGroupName to Azure"
	$Error[0]
	exit 1
}

Write-Output "Complete!"
exit 0
