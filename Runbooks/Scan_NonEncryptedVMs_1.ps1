$RBname = "Encrypt_VMs_2"

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

Function ScanEnv {

    $checkvm = Get-AzVM |

    ForEach-Object {

        $VM = $_.Name
        $RG = $_.ResourceGroupName
        $Os = $_.StorageProfile.OsDisk.OsType

        # Check Encryption status
        # If VM isn't encrypted, inject info into params
        $status = (Get-AzVmDiskEncryptionStatus  -ResourceGroupName "$RG" -VMName "$VM")
        
        if ($status.OsVolumeEncrypted -eq "NotEncrypted" -or $status.DataVolumesEncrypted -eq "NotEncrypted") {

            write-output "Injecting " + $VM + " info into Runbook"

            $Params = @{
                "VMName" = "$VM"
                "RGName" = "$RG"
                "OsType" = "$Os"
            }

            $RBJob = Start-AutomationRunbook -Name $RBname -Parameters $Params

            if($RBJob) {
                write-output "Provisioning has started for Virtual Machine - [$VM] in [$RG]"
            }
            else {
                write-output "Provisioning failed for Virtual Machine - [$VM] in [$RG]"
            }
        }
        else {
            write-output "$VM in $RG is already encrypted"
        }
    }
}

ScanEnv

write-output $Params
