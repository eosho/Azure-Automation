[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [String]$EnvironmentName,

    [Parameter(Mandatory = $true)]
    [String]$projectName,

    [Parameter(Mandatory = $true)]
    [String]$Region
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

#Connect-AzAccount -EnvironmentName AzureUSGovernment

# Tag values go here
$Tags = @{
    "ProjectName" = "$projectName"
    "Environment" = "$EnvironmentName"
}

try {
    # Create Resource Group
    Write-Host "`nChecking for presence of RG '$ResourceGroupName'"
    $RGExists = (Get-AzResourceGroup -Name $ResourceGroupName)

    if (!$RGExists) {
        Write-Host "`nResource group '$ResourceGroupName' does not exist..."
        Write-Host "Creating resource group '$ResourceGroupName' in location '$Region'"
        New-AzResourceGroup -Name $ResourceGroupName -Location $Region

        Write-Host "`nTagging resource group '$ResourceGroupName'"
        Set-AzResourceGroup -Name $ResourceGroupName -Tag $Tags
    }
    else {
        Write-Host "`nUsing existing resource group '$ResourceGroupName'"
    }
}
catch {
    Write-Output "Error happened deploying resource group"
}

# Get account
#$createdBy = (Get-AzContext | Select-Object -ExpandProperty Account).Id

# Set the Policy Parameter
$policyParam = @"
    {
        "Environment": {
            "type": "String",
            "metadata": {
                "displayName": "required value for Environment Name tag"
            },
  
        },
        "ProjectName": {
            "type": "String",
            "metadata": {
                "displayName": "required value for project Name tag"
            },
  
        }
    }
"@

# Create the Policy Definition (Subscription scope)
# policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62 - enforces tags
# policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498 - denies tags
$definition = @"
    [
    {
		"policyDefinitionId": "/providers/Microsoft.Authorization/policyDefinitions/2a0e14a6-b0a6-4fab-991a-187a4f81c498",
		"parameters": {
			"tagName": {
				"value": "Environment"
			},
			"tagValue": {
				"value": "[parameters('Environment')]"
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
				"value": "[parameters('projectName')]"
			}
		}
	},
]
"@

# Set the scope to a resource group; may also be a resource, subscription, or management group
$scope = Get-AzResourceGroup -Name $ResourceGroupName

# Create policy per RG
$policyset = New-AzPolicySetDefinition -Name "$ResourceGroupName-billing-tags" `
    -DisplayName "Billing Tags Policy Initiative" `
    -Description "Specify Environment and projectName tags" `
    -PolicyDefinition $definition -Parameter $policyParam 

# Assign policy assignment to RG
$assignment = New-AzPolicyAssignment -PolicySetDefinition $policyset `
    -Name "$ResourceGroupName - TAG Enforcement" `
    -Scope $scope.ResourceId `
    -PolicyParameterObject $Tags

$id = $assignment.ResourceId
Write-Output "Policy ID -  $id"

if ($null -eq $assignment) {
    Write-Output "`nFailed to deploy policy..."
}
else {
    Write-Output "`npolicy definitiion was successful..."
    Get-AzPolicyAssignment -Id $id
}
