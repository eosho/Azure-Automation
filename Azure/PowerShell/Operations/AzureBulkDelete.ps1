$VerbosePerference = "SilentlyContinue"

$SelectSubscription = Get-AzureRmSubscription | Out-GridView -Title "Select a Subscription" -OutputMode Single

Set-AzureRmContext -Subscription $SelectSubscription

$SelectRG = Get-AzureRmResourceGroup | Out-GridView -Title "Select Resource Group" -OutputMode Single

$ResourceSelection = Get-AzureRmResource -ResourceGroupName $SelectRG.ResourceGroupName | Out-GridView -Title "Select Resources to Remove" -OutputMode Multiple

$ResourceSelection = $ResourceSelection | Out-GridView -Title "Re-Select Resources to Remove" -OutputMode Multiple

If ($ResourceSelection.Count -eq 0) {
  Break
}

Function BulkDeleteResource {
    [CmdletBinding()]

Param (
    [Parameter(Mandatory=$True)]
    [Object[]]$ResourcesToRemove,
    [Parameter(Mandatory=$False)]
    [switch]$Delete = $False
  )

BEGIN {
    $AzureResourceTypes = @(
        "Microsoft.Compute/virtualMachines"
        "Microsoft.Compute/virtualMachines/extensions"
        "Microsoft.Compute/availabiliySets"
        "Microsoft.Network/networkInterfaces"
        "Microsoft.Network/privateIPAddresses"
        "Microsoft.Network/publicIPAddresses"
        "Microsoft.Network/networkSecurityGroups"
        "Microsoft.Compute/disks"
        "Microsoft.Storage/storageAccounts"
        "Microsoft.Network/virtualNetworks"
    )

    $VerbosePreference = "continue"
}

PROCESS {
    foreach ($AzureResourceType in $AzureResourceTypes) {
        Write-Output "Getting resource type $($AzureResourceType)"
    
        $ResourcesToRemove | Where-Object { $_.ResourceType -eq $AzureResourceType } |
        ForEach-Object {
            Write-Output "Deleting $($_.Name)"
            If ($Delete -eq $True) {
                $_ | Remove-AzureRmResource -Force
            }
            else {
                $_ | Remove-AzureRmResource -Force -WhatIf
            }      
        }
  
        $ResourcesToRemove = $ResorucesToRemove | Where-Object { $_.ResoueceType -ne $AzureResourceType }
    }

    if ($ResourcesToRemove.Count -gt 0) {
        Write-Output "Processing the remaining resource types"
        $ResourcesToRemove | 
        ForEach-Object {
            Write-Output "Deleting $($_.Name)"

            if ($Delete -eq $True) {
                $_ | Remove-AzureRmResource -Force
            }
            else {
                $_ | Remove-AzureRmResource -Force -WhatIf
            }
        }

        $ResourcesToRemove = $null
        }
    } #End PROCESS

} #End BulkDeleteResource

Write-Host "Performing Remove-AzureRmResource -WhatIf on all selected resources to incite fear" - ForegroundColor Red
Start-Sleep -s 10

BulkDeleteResource $ResourceSelection

Write-Host "`nType ""Delete"" to Remove all resources, or Ctlr-C to Exit Now" -ForegroundColor Green
$HostInput = $Null
$HostInput = Read-Host "Hmmm...Final Answer? (Y or N)"
if ($HostInput = "Y") {
    BulkDeleteResource $ResourceSelection -Delete
}
