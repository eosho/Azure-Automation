Param(
    [Parameter(Mandatory = $true)]
    [string]$RGName,
    [Parameter(Mandatory = $true)]
    [string]$VMName,
    [Parameter(Mandatory = $true)]
    [string]$OsType
)

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Requires -Version 3.0
#Requires -Module Az.Resources
#Requires -Module Az.KeyVault

$ErrorActionPreference = 'continue'

$kvRGName = "core-resources-rg"
$location = "East US"
$kvName = "core-keyvault-01"

Function RegisterResourceProvider {
    Param(
        [string]$ResourceProviderNamespace = "Microsoft.KeyVault"
    )

    Write-Output "Checking resource provider '$ResourceProviderNamespace'";
    $check = (Get-AzResourceProvider -ProviderNamespace "$ResourceProviderNamespace")

    if ($check.RegistrationState -ne "Registered") {
        Write-Output "$ResourceProviderNamespace has not been enabled...enabling now"
        Get-AzResourceProvider -ProviderNamespace "$ResourceProviderNamespace"
    }
    else {
        Write-Output "$ResourceProviderNamespace has already been registered"
    }
}

#RegisterResourceProvider

$checkKV = (Get-AzKeyVault -VaultName $kvName)

if ($null -eq $checkKV) {
    Write-Output "Creating KeyVault - $kvName"

    New-AzKeyVault -Location $location `
        -ResourceGroupName $kvRGName `
        -VaultName $kvName `
        -EnabledForDiskEncryption
}
else {
    $checkKV.VaultName + " has already been created"
}

$checkkey = (Get-AzKeyVaultKey -VaultName $kvname -Name myKey)

if ($null -eq $checkkey) {
    Write-Output "Adding keyvault key to the vault"
    Add-AzKeyVaultKey -VaultName $kvname `
        -Name "myKey" `
        -Destination "Software"
}
else {
    Write-Output "Key has already been created....continuing"
}

$diskEncryptionKeyVaultUrl = $checkkv.VaultUri;
$keyVaultResourceId = $checkKV.ResourceId;
$keyEncryptionKeyUrl = $checkkey.Key.kid;

Function EncryptVM {
    if ($OsType -eq "Windows") {
        Write-Output "Working with Windows VM"

        Write-Output "Working with Virtual Machine - [$VMName] in RG [$RGName]"
        Write-Output "Checking current VM encryption status"

        # Run function
        Write-Output "$VMName's OS/DataDisk are not encrypted...Encrypting now"
        Set-AzVMDiskEncryptionExtension -ResourceGroupName $rgName `
                        -VMName "$VMName" `
                        -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl `
                        -DiskEncryptionKeyVaultId $keyVaultResourceId `
                        -KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
                        -KeyEncryptionKeyVaultId $keyVaultResourceId -WhatIf
    }
    else {
        Write-Output "Add code for Linux later"
        # Run function
    } 
}

Write-Output "Getting VM state..."
$VMStatus = (Get-AzVM -ResourceGroupName $RGName -Name $VMName -Status).Statuses[1].DisplayStatus

if ($VMStatus -like "*VM running*") {
    EncryptVM
}
else {
    Write-Output "$VMName is not running... I will start it now"
    Start-AzVM -ResourceGroupName $RGName -Name $VMName -WhatIf
    EncryptVM
}
