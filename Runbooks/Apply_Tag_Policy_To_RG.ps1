[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [String]$EnvironmentName,
    [Parameter(Mandatory = $true)]
    [String]$projectName
)

$AzureAutomationAccount = "poc-automation-acct"
$AzureAutomationAccountRG = "POC-RESOURCES-RG"

try {
    $servicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
    Write-Output "Logging in to Azure...`n"
    Add-AzureRMAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -EnvironmentName AzureCloud
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection AzureRunAsConnection not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

$RGExists = (Get-AzureRmResourceGroup -Name $ResourceGroupName)

if (!$RGExists) {
    Write-Host "`nResource group '$ResourceGroupName' does not exist..."
    Exit 1
}
else {
    Write-Host "`nFound '$ResourceGroupName'... continuing"
}

# Get account
#$createdBy = (Get-AzContext | Select-Object -ExpandProperty Account).Id

# Set the Policy Parameter
$policyParam = @"
    {
        "EnvironmentValue": {
            "type": "String",
            "metadata": {
                "displayName": "required value for Environment Name tag"
            },
  
        },
        "ProjectNameValue": {
            "type": "String",
            "metadata": {
                "displayName": "required value for project Name tag"
            },
  
        }
    }
"@

# Create the Policy Definition (Subscription scope)
$definition = @"
    [
	{
		"policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498",
		"parameters": {
			"tagName": {
				"value": "Environment"
			},
			"tagValue": {
				"value": "[parameters('EnvironmentValue')]"
			}
		}
	},
	{
		"policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498",
		"parameters": {
			"tagName": {
				"value": "projectName"
			},
			"tagValue": {
				"value": "[parameters('projectNameValue')]"
			}
		}
	}
]
"@

# Tag values go here
$params = @{
    "projectNameValue" = "$projectName"
    "EnvironmentValue" = "$EnvironmentName"
}

# Set the scope to a resource group; may also be a resource, subscription, or management group
$scope = Get-AzureRmResourceGroup -Name $ResourceGroupName

# Create policy per RG
$policyset = New-AzureRmPolicySetDefinition -Name "$ResourceGroupName-billing-tags" `
    -DisplayName "Billing Tags Policy Initiative" `
    -Description "Specify Environment and projectName tags" `
    -PolicyDefinition $definition -Parameter $policyParam 

# Assign policy assignment to RG
$assignment = New-AzureRmPolicyAssignment -PolicySetDefinition $policyset `
    -Name "$ResourceGroupName - Enforce Resource tag assignment" `
    -Scope $scope.ResourceId `
    -PolicyParameterObject $params

if ($null -eq $assignment) {
    Write-Output "Failed to deploy policy..."
}
else {
    Write-Output "policy definitiion was successful..."
}
