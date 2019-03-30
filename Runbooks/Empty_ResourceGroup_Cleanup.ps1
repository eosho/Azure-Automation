$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

#Get all ARM resources from all resource groups
$ResourceGroups = Get-AzureRmResourceGroup 

foreach ($ResourceGroup in $ResourceGroups) {    
    Write-Output ("Showing resources in resource group " + $ResourceGroup.ResourceGroupName)
    $Resources = Get-AzureRmResource -ResourceGroupName $ResourceGroup.ResourceGroupName | Select Name, ResourceType
    Write-Output $Resources.Count

    if ($null -eq $Resources) {
        Write-Output ("Resource group " + $ResourceGroup.ResourceGroupName + " is empty")
        Remove-AzureRmResourceGroup -Name $ResourceGroup.ResourceGroupName -Verbose -Force
    }
    else {
        ForEach ($Resource in $Resources) {
            Write-Output ($Resource.ResourceName + " of type " + $Resource.ResourceType + " & name - " + $Resource.Name)
        }
        Write-Output ("")
    }
} 
