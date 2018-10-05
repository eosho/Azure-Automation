# Script shows a GUI for deleting all Resources in a Resource Group

# Login to Azure and check for success
$Login = Login-AzureRmAccount

if ($Login) {
    Write-Host "Connected to Azure...`n"
}
else {
    Write-Host "Error... failed to connect to Azure 'n"
    Exit 1
}

$SelectSubscription = Get-AzureRmSubscription | Out-GridView -Title "Select a Subscription" -OutputMode Single

Set-AzureRmContext -Subscription $SelectSubscription

$SelectRG = Get-AzureRmResourceGroup  | Out-GridView -Title "Select Resource Group" -OutputMode Single

$ResourceSelection =  Get-AzureRmResource -ResourceGroupName $SelectRG.ResourceGroupName  | Out-GridView -Title "Select Resources to Remove" -OutputMode Multiple

#$ResourceSelection =  $ResourceSelection | Out-GridView -Title "Re-Select Resources to Remove" -OutputMode Multiple

If ($ResourceSelection.Count -eq 0) {
    Write-Host "Resource group $($SelectRG.ResourceGroupName) is empty... Exiting"
    Break
}

Function BulkDeleteResource {
[CmdletBinding()]

Param(
    [Parameter(Mandatory=$True)]
    [object[]]$ResourcesToRemove,
    [Parameter(Mandatory=$False)]
    [switch]$Delete = $False
    )

BEGIN {
    $AzureResourceTypes = @(
        "Microsoft.Compute/virtualMachines"
        "Microsoft.Compute/virtualMachines/extensions"
        "Microsoft.Compute/availabilitySets"
        "Microsoft.Network/networkInterfaces"
        "Microsoft.Network/publicIPAddresses"
        "Microsoft.Network/privateIPAddresses"
        "Microsoft.Network/networkSecurityGroups"
        "Microsoft.Compute/disks"
        "Microsoft.Storage/storageAccounts"
        "Microsoft.Network/virtualNetworks"
    )
    
    $VerbosePreference = "continue"
}

PROCESS {
    foreach ($AzureResourceType in $AzureResourceTypes) {
    Write-Verbose "Processing Resource Type $($AzureResourceType)"

    $ResourcesToRemove |
        Where-Object { $_.Resourcetype -eq $AzureResourceType } |
        ForEach-Object {
            Write-Verbose "Deleting $($_.Name)"
            If ($Delete -eq $True) {
                $_ | Remove-AzureRmResource -Force 
            } 
            else {
                $_ | Remove-AzureRmResource -Force -WhatIf 
            }
        }

        $ResourcesToRemove = $ResourcesToRemove | Where-Object { $_.Resourcetype -ne $AzureResourceType }
    }

    If ($ResourcesToRemove.Count -gt 0) {
        Write-Verbose "Processing Resource Type OTHER"
        $ResourcesToRemove | 
            ForEach-Object {
            Write-Verbose "Deleting $($_.Name)"
    
            If ($Delete -eq $True) {
                $_ | Remove-AzureRmResource -Force 
            }
            Else {
                $_ | Remove-AzureRmResource -Force -WhatIf 
            }
        }
    
        $ResourcesToRemove = $null
    
        }

    } #End PROCESS

} #End BulkDeleteResource

# Dry run to scare folks
Write-Host "Performing Remove-AzureRmResource -WhatIF on all selected resouces to incite fear" -ForegroundColor Red
Start-Sleep -s 10

BulkDeleteResource $ResourceSelection

# Confirm deletion of all resources
Write-Host "`nType ""Delete"" to Remove Resources, or Ctrl-C to Exit" -ForegroundColor Green
$HostInput = $Null
$HostInput = Read-Host "Final Answer" 
If ($HostInput = "Delete") {
    BulkDeleteResource $ResourceSelection -Delete
}

$DeleteRG = $Null
$DeleteRG = Read-Host "Confirm you want to delete the Resource Group (Y or N)"
if ($DeleteRG = "Y") {
    # Delete Resource Group once all resources have been deleted
    Write-Host "`nDeleting Resource group $($SelectRG.ResourceGroupName)" -ForegroundColor Green
    $ResourceSelection =  Remove-AzureRmResourceGroup -Name $SelectRG.ResourceGroupName -Force
    Write-Host "Done"
}
else {
    Write-Host "Resource Group not deleted"
}
