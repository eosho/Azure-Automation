<#
.SYNOPSIS
Creates Resource group based on CSV file

.DESCRIPTION
Deploys Resource Group based on DeploymentStatus = 1
 - DeploymentStatus codes:
  - 0 = Not ready to be deployed
  - 1 = Ready to be deployed
  - 2 = Issue occured during deployment
  - 3 = Successfully deployed

.PARAMETER filepath
File path where CSV is located for deployment
#>

[CmdletBinding()]
param(
    [Parameter()]
    [String]$filepath = "C:\demo.csv"
)

# Clear screen
Clear-Host

$ProjectCsv = @()
$ProjectCsv = Import-Csv -Path $filepath

foreach ($data in $ProjectCsv) {
    $info += "$($data.ProjectName),$($data.DeploymentState),$($data.RGName),$($data.Subscription),$($data.Region),$($data.TagOwner),$($data.TagEnvironment)"

    if ($data.DeploymentState -ne 1) {
        Write-Host "`n$($data.ProjectName) is not ready to be deployed - Status is $($data.DeploymentState)" -ForegroundColor Yellow
        continue
    }
    else {
        Write-Host "`nDeploying $($data.ProjectName)" -ForegroundColor Green
    }

    # Select Subscription from CSV
    Select-AzSubscription -SubscriptionId "$($data.Subscription)"
    $GetSub = Get-AzSubscription -SubscriptionId "$($data.Subscription)"

    Write-Host "`nSubscription has been changed to - $($GetSub.Name)" -ForegroundColor Cyan

    # Tag Objects
    $Tags = @{
        "Owner"       = "$($data.TagOwner)"
        "Environment" = "$($data.TagEnvironment)"
        "ProjectName" = "$($data.ProjectName)"
    }

    Write-Host "`nTag Object values" -ForegroundColor Green
    $Tags | Format-Table

    try {
        # Create Resource Group
        Write-Host "`nChecking for presence of RG '$($data.RGName)'"
        $RGExists = Get-AzResourceGroup -Name $($data.RGName) -Location $($data.Region)

        if (!$RGExists) {
            Write-Host "`nResource group '$($data.RGName)' does not exist..."
            Write-Host "Creating resource group '$($data.RGName)' in location '$Region'"
            New-AzResourceGroup -Name $($data.RGName) -Location $Region

            Write-Host "`nTagging resource group '$($data.RGName)'"
            Set-AzResourceGroup -Name $($data.RGName) -Tag $Tags
        }
        else {
            Write-Host "`nUsing existing resource group '$($data.RGName)'"
        }

        # Update Deployment status after RG creation
        Import-Csv -Path $filepath | ForEach-Object {
            if ($_.DeploymentState -eq 1) {
                write-Host "`nUpdating deployment status for project(s) - $($data.ProjectName)" -ForegroundColor Green
                $_.DeploymentState = 3
            }
            $_
        } | Export-Csv C:\Users\eroshoko\Desktop\demo.csv -NoTypeInformation
        Get-Content C:\demo-success.csv
    }
    catch {
        Write-Host "Error occured deploying $($data.ProjectName). Please try again"
        Import-Csv -Path $filepath | ForEach-Object {
            if ($_.DeploymentState -eq 1) {
                write-Host "`nUpdating deployment status for project(s) - $($data.ProjectName)" -ForegroundColor Green
                $_.DeploymentState = 2
            }
            $_
        } | Export-Csv C:\Users\eroshoko\Desktop\demo.csv -NoTypeInformation
        Get-Content C:\demo-failed.csv

    }
}
