$SelectSubscription = Get-AzureRmSubscription | Out-GridView -Title "Select a Subscription" -OutputMode Single

Set-AzureRmContext -Subscription $SelectSubscription

$SelectRG = Get-AzureRmResourceGroup  | Out-GridView -Title "Select Resource Group" -OutputMode Single

$ResourceSelection =  Get-AzureRmResource -ResourceGroupName $SelectRG.ResourceGroupName  | Out-GridView -Title "Select Resources to Remove" -OutputMode Multiple

#$ResourceSelection =  $ResourceSelection | Out-GridView -Title "Re-Select Resources to Remove" -OutputMode Multiple

If ($ResourceSelection.Count -eq 0) {
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


Write-Host "Performing Remove-AzureRmResource -WhatIF on all selected resouces to incite fear" -ForegroundColor Red
Start-Sleep -s 10

BulkDeleteResource $ResourceSelection

Write-Host "`nType ""Delete"" to Remove Resources, or Ctrl-C to Exit" -ForegroundColor Green
$HostInput = $Null
$HostInput = Read-Host "Final Answer" 
If ($HostInput = "Delete" ) {
    BulkDeleteResource $ResourceSelection -Delete
}
