# Script uses VM Disk's cration date view to tag VM with creation date

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$VM,
    [Parameter(Mandatory = $true)]
    [String]$RG
)

# Begin
$Info = Get-AzVM -ResourceGroupName $RG -Name $VM
$DiskName = $Info.StorageProfile.OsDisk.Name
Get-AzDisk -ResourceGroupName $RG -DiskName $DiskName| Where-Object {$_.TimeCreated -le (Get-Date)} |
    Select-Object Name, ManagedBy, ResourceGroupName, TimeCreated, Tag |
    ForEach-Object {
    Try { 
        $ErrName = $_.Name 
        $AzDiskManagedBy = $_.managedby | Split-path -leaf 
        $AzDiskManagedByRG = $_.ResourceGroupName 
        $CreationDate = $_.TimeCreated.ToString('yyyyMMdd')
        $DiskName = $_.Name
        $OS = (Get-AzVM -name $AzDiskManagedBy -ResourceGroup $AzDiskManagedByRG).StorageProfile.ImageReference.Offer 
        $SKU = (Get-AzVM -name $AzDiskManagedBy -ResourceGroup $AzDiskManagedByRG).StorageProfile.ImageReference.SKU

        $Table += [pscustomobject]@{VMName = $AzDiskManagedBy; Created = $CreationDate; ResourceGroup = $AzDiskManagedByRG; OperatingSystem = $OS; SKU = $SKU; DiskName = $DiskName} 
                
        Write-Host "Tagging VM with CreationDate" -ForegroundColor Cyan
        Update-AzVM -ResourceGroupName $Info.ResourceGroupName -VM $Info -Tag @{"CreationDate" = "$CreationDate"}

        $validate = (Get-AzVM -ResourceGroupName $RG -Name $VM).Tags
        if ($validate.Keys -notlike "*creationDate*") {
            "something happened"
        }
        else {
            "all good here"
            "Tag value is " + $validate.Keys + " | Key is: " + $validate.Values
        }
    } 
    Catch { 
        Write-Host "Cannot determine machine name associated with disk: [$ErrName]. Skipping drive-check for this item..." -ForegroundColor Yellow 
        Write-Host "Continue Checking Subscription: $Subscription. for any Azure VMs and their creation date. This process may take a while. Please wait..." -ForegroundColor Green 
    }
}

$UniqueVMs = $Table | Sort -Unique -Property VMName 
$UniqueVMs
