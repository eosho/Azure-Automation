# NOTE - VM and KeyVault must reside in the same ResourceGroup

Param (
    [parameter(Mandatory = $true)]
    [string]$SubscriptionName,
    [parameter(Mandatory = $true)]
    [string]$ResourceGroupName
)

Clear-Host

$ErrorActionPreference = "Continue"

$SubscriptionName = Select-AzSubscription -Subscription "$SubscriptionName"

$TemplateFilePath = "Encrypt_WinVM_noAAD.json"

# Login to Azure
Write-Host "`nChecking Azure login..."
try {
    Get-AzContext
}
catch {
    if ($_ -like "*Connect-AzAccout to login*") {
        Write-Host "`nYou are not logged in to Azure. I will prompt you now..."
        Connect-AzAccount
    }
}

$kekName = "computers"

$CheckVM = (Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName)
$CheckKeyVault = (Get-AzKeyVault -ResourceGroupName $ResourceGroupName)

$ResourceGroupName = $CheckKeyVault.ResourceGroupName
$Location = $CheckKeyVault.Location
$KVName = $CheckKeyVault.VaultName

if ($null -eq $CheckVM) {
    Write-Output "$VMName - VM not found."
    Exit 1
}
elseif ($null -eq $CheckKeyVault) {
    Write-Output "$KVName not found."
    Exit 1
}
else {
    Write-Output "`nVM - $VMName and KV - $KVName found"
    Write-Output "`nEnabling KV for Encryption..."
    Set-AzKeyVaultAccessPolicy -VaultName $KVName -ResourceGroupName $ResourceGroupName -EnabledForDiskEncryption

    $key = (Add-AzKeyVaultKey -VaultName $KVName -Name $kekName -Destination 'software')
    $kekURL = $key.Id
}

# Template parameter objects
$TemplateParameters = @{
    "vmName"                = "$VMName"
    "keyVaultName"          = "$KVName"
    "keyVaultResourceGroup" = "$ResourceGroupName"
    "keyEncryptionKeyURL"   = "$kekURL"
    "volumeType"            = "All" # Default is All
    "location"              = "$Location"
}

$deploymentName = ("$VMName" + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmmss-FFFF'))

Write-Output "`nDeploying $deploymentName to resource group $ResourceGroupName"

# Begin Deployment
New-AzResourceGroupDeployment -Name $deploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile $TemplateFilePath `
    -TemplateParameterObject $TemplateParameters `
    -Force `
    -Verbose

# Validate encryptin is done
$CheckStatus = (Get-AzVMDiskEncryptionStatus -ResourceGroupName $ResourceGroupName -VMName $VMName)

if ($CheckStatus.ProgressMessage -notlike "*succeeded*") {
    Write-Output "Disk Encryption Failed..."
    Exit 1
}
else {
    Write-Output "Disk Encryption Successful..."
    Exit 0
}
