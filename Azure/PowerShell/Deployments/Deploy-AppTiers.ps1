<#
    .SYNOPSIS
        Deploys an Azure VM

    .NOTES
        Due to the large amount of information required to deploy a VM. The data is exposed as
        variables that should be modified per VM to restore. There is example information already
        in place to help decipher the expected data structure.

        Not all of the data is strictly required for the deployment of a VM. AvailabilitySet and
        diagnosticsStorageUri are optional.

    .PARAMETER AdminCredentials
        Admin credentials of VM being deployed

    .PARAMETER SubscriptionID
        ID of subscription to deploy too

    .PARAMETER ResourceGroupName
        Name of resource group to deploy too

    .PARAMETER ResourceGroupLocation
        Azure region location to deploy VM too. If storage account does not exist, it will be created here too
#>

#Requires -Version 5

Param
(
    [parameter(Mandatory)]
    [pscredential]
    $AdminCredentials,

    [parameter(Mandatory=$True)]
    $SubscriptionID,

    [parameter(Mandatory=$True)]
    $ResourceGroupName
)

cls

$ErrorActionPreference = "Continue"

# login to Azure
Write-Host "`nChecking Azure login..."
try {
    Get-AzContext
}
catch {
    if ($_ -like "*Connect-AzAccout to login*")
{
    Write-Host "`nYou are not logged in to Azure. I will prompt you now..."
    Connect-AzAccount
    }
}

#You need to modify
$Environment = "DEVTEST"
$AppNameCode = "DEMO"

$AppTiers = @(
    "APP"
    "WEB"
    "SSRS"
)

#Set environment variables
if ($Environment -eq "DEVTEST")
{
    $SubscriptionName = "Visual Studio EnterPrise"
    $Suffix = 80
}
elseif ($Environment -eq "NPROD")
{
    $SubscriptionName = "Visual Studio EnterPrise"
    $Suffix = 40
}
elseif ($Environment -eq "PROD")
{
    $SubscriptionName = "Visual Studio EnterPrise"
    $Suffix = 60
}
else
{
    Write-Output "Invalid Environment..Enter either DevTest, NProd or Prod and try again" -ForegroundColor Red
}

#Select Subscription
$SubscriptionName = Select-AzSubscription -Subscription "$SubscriptionName"

$TemplateFilePath = "C:\Users\eroshoko\OneDrive - Microsoft\Documents\Azure\templates\existing-vnet\coms-template.json"

foreach ($AppTier in $AppTiers)
{
    Write-Host "`nDeploying '$($AppTier)'"

    # vm info
    $ResourceGroupName = "DEMO-$Environment-RG"
    $Region = "EastUS"
    $vmName = "VAC21$AppTier$AppNameCode$Suffix"
    $password = [System.Web.Security.Membership]::GeneratePassword(12,0)
    $username = "azureuser"
    $SecurePass = ConvertTo-SecureString $password -AsPlainText -Force
    $SecureUser = ConvertTo-SecureString $username -AsPlainText -Force
    $KeyVaultName = "VAC21-$AppNameCode-$Environment-KV"
    $BackupVaultName = "$AppNameCode-$Environment-BK-VAULT"

    #You need to modify networking variables
    $TemplateParameters = @{
        "vmNamePrefix" = "$vmName"
        "numberOfInstances" = 3
        "vmSize" = "Standard_DS2_v2"
        "AdminUsername" = "$username"
        "AdminPassword" = "$SecurePass"
        "loadBalancerName" = "$AppNameCode-$Environment-$AppTier-LB"
        "AvailabilitySetName" = "$AppNameCode-$Environment-$AppTier-AVSET"
        "virtualNetworkNewOrExisting" = "existing" #or new
        "OSType" = "Windows" #or Linux
        "storageAccountType" = "Standard_LRS"
        "networkSecurityGroupName" = "$AppNameCode-$Environment-$AppTier-NSG"
        "virtualNetworkResourceGroup" = "POC-VNET-RG"
        "virtualNetworkName" = "POC-VNET"
        "SubnetName" = "POC-Subnet-01"
    }

    # Resource Group tags
    $Tags = @{
        "Environment" = ""
        "Administration" = ""
        "Project Name" = ""
    }

    if ($AppNameCode -eq $null -and $Environment -eq $null)
    {
        Write-Host "`n Enter a valid Application name code or Environment"
        exit 1
    }
    else {
        Write-Host "`nDeloying resources for $AppNameCode in $Environment"
    }

    $return = $false

    Write-Host "`nChecking for presence of RG $ResourceGroupName"
    $Exists = Get-AzResourceGroup -Name $ResourceGroupName -Location $Region

    if (!$Exists)
    {
        Write-Host "`nResource group '$ResourceGroupName' does not exist..."
        Write-Host "Creating resource group '$ResourceGroupName' in location '$Region'"
        New-AzResourceGroup -Name $ResourceGroupName -Location $Region

        Write-Host "`nTagging resource group '$ResourceGroupName'"
        Set-AzResourceGroup -Name $ResourceGroupName -Tag $Tags
    }
    else
    {
        Write-Host "`nUsing existing resource group '$ResourceGroupName'"
        $return = $true
    }

    <#
    $storageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue

    if ($null -eq $storageAccount)
    {
        $storageAccount = New-AzureRmStorageAccount -StorageAccountName $storageAccountName `
                                                    -Type 'Standard_LRS' `
                                                    -ResourceGroupName $ResourceGroupName `
                                                    -Location $ResourceGroupLocation
    }
    #>

    #region deploy the VM
    $deploymentName = ("$AppNameCode" + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmmss-FFFF'))

    Write-Output "Deploying $deploymentName to resource group $ResourceGroupName"

    New-AzResourceGroupDeployment -Name $deploymentName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -TemplateFile $TemplateFilePath `
                                       -TemplateParameterObject $TemplateParameters `
                                       -Force `
                                       -Verbose

    #Enable VM backup
    $GetVMs = Get-AzVM -ResourceGroupName "POC-RG"
    $GetVMs.Count

    <#foreach ($VM in $GetVMs) 
    {
            $vmList = Get-AzVM -ResourceGroupName "POC-RG" -Name $GetVMs.Name
    
            Write-Host "`nCreating backup Vault..." -ForegroundColor Green
            New-AzRecoveryServicesVault -ResourceGroupName $vmList.ResourceGroupName `
                                        -Name "$BackupVaultName" `
                                        -Location "EastUS"
        
            Write-Output "`nEnabling backup for '$vmList.Name'"
            Get-AzRecoveryServicesVault -Name "$BackupVaultName" | Set-AzRecoveryServicesVaultContext
            #-ResourceGroupName $ResourceGroupName

            $Policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "DefaultPolicy"
            Write-Host $Policy

            Enable-AzRecoveryServicesBackupProtection -ResourceGroupName $_.ResourceGroupName `
                                        -Policy $Policy `
    
    
    }#>

    #Create Keyvault to save VM credentials
    
    $CheckVeyVault = Get-AzKeyVault -VaultName $KeyVaultName
    if (!$CheckVeyVault)
    {
        Write-Host "`nCreating Keyvault..."
        New-AzKeyVault -Name $KeyVaultName `
                        -ResourceGroupName $ResourceGroupName `
                        -Location $Region
    }
    else
    {
        Write-Host "KeyVault '$KeyVaultName' is already created.." -ForegroundColor Yellow
    }
    Write-Host "`nAdding secrets to KeyVault..."
    Set-AzKeyVaultSecret -VaultName "$KeyVaultName" `
                        -Name "localadminuser" `
                        -SecretValue $SecureUser

    Set-AzKeyVaultSecret -VaultName "$KeyVaultName" `
                        -Name "localadminpassword" `
                        -SecretValue $SecurePass

    sleep 10

    Write-Host "`nRemember to create the Backup Vault and enable backup for the VMs"
    Write-Host "`nRemember to assign the correct group to Keyvault for access"
    
}

Write-Host "All done..."
#endregion
