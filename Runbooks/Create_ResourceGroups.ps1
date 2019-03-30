Param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$ProjectName
)

$AzureAutomationAccount = "poc-automation-acct"
$AzureAutomationAccountRG = "POC-RESOURCES-RG"
$AzureAutomationAccountSubId = "f2d85cf0-b21c-4794-a259-f508c89d08c2"
$RBName = "Update_DB"

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

function Invoke-SQL {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [Parameter(Mandatory = $true)]
        [string]$dbName,
        [Parameter(Mandatory = $true)]
        [string]$uid,
        [Parameter(Mandatory = $true)]
        [string]$pw,
        [Parameter(Mandatory = $true)]
        [string]$sqlQuery
    )

    $Conn = New-Object System.Data.SqlClient.SQLConnection
    $Conn.ConnectionString = "Server=$Server;Database=$dbName;Integrated Security=False;User Id=$uid;Password=$pw"
    $Command = New-Object System.Data.SqlClient.SqlCommand($sqlQuery, $conn)
    $Conn.Open()
    $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter $Command
    $DataSet = New-Object System.Data.DataSet
    $Adapter.Fill($DataSet) | Out-Null
    $Conn.Close()
    $DataSet.Tables
}

Write-Output "Validating SQL creds and details..."

Write-Output "Getting DB User"
$uid = Get-AutomationVariable -Name 'User'

write-output "Getting Database..."
$DBname = "projectsdb"

Write-Output "Getting DB Password..."
$pw = Get-AutomationVariable -Name 'Password'

Write-Output "Getting DB Server..."
$Server = Get-AutomationVariable -Name 'Server'

Write-Output "Getting Environment name for $ProjectName"
$EnvCheck = "SELECT [SubscriptionName] FROM [dbo].[poc]  where [ProjectName] = '$ProjectName'"
$ProjectEnvCheck = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $EnvCheck

Write-Output "Getting RG Tag info for $ProjectName"
$TagsCheck = "select [TagOwner], [TagEnvironment] from [dbo].[poc] where ProjectName = '$ProjectName'"
$ProjectTagCheck = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $TagsCheck

Write-Output "Getting Location name for $ProjectName"
$LocationCheck = "SELECT [Location] FROM [dbo].[poc]  where [ProjectName] = '$ProjectName'"
$ProjectLocationCheck = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $LocationCheck

# Variables
$EnvironmentName = $($ProjectEnvCheck.EnvironmentName)
$ProjectTags = $($ProjectTagCheck.ProjectTags)
$Location = $($ProjectLocationCheck.Location)

<#
$Tags += @{
    Owner = "$($ProjectTagCheck.TagOwner)"
    Environment = "$($ProjectTagCheck.TagEnvironment)"
}

$Tags += @{}
$Tags.Add($('Owner'), ("$($ProjectTagCheck.TagOwner)"))
$Tags.Add($('Environment'), ("$($ProjectTagCheck.TagEnvironment)"))

param (
    [Parameter()]
    [string]$ResourceGroupNames,
    [Parameter()]
    [string]$EnvironmentName,
    [Parameter()]
    [string]$ProjectTags,
    [Parameter()]
    [string]$Location
)#>

Select-AzureRmSubscription -SubscriptionId $AzureAutomationAccountSubId
  
$return = $false
Write-Output "Checking for presence of $ResourceGroupName in $EnvironmentName"

$RGExists = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue

if ($RGExists) {
    Write-Output "Resource Group Already Exists"
    $return = $true
}
else {
    Write-Output "Resource Group not created, creating now..."
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue

    #Write-Output "Tagging Resource Group..."
    #Set-AzureRmResourceGroup -Name $ResourceGroupName -Tag $Tags
    $RGExists = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue
    
    If ($RGExists) {
        $return = $true

        #$Name = "$($Project.ProjectName)"
        $params = @{"ProjectName" = $ProjectName}

        $RBJob = Start-AutomationRunbook -Name $RBname -Parameters $params #-resourceGroupName $AzureAutomationAccountRG -AutomationAccountName $AzureAutomationAccount 
        #sleep 15
        if($RBJob)
        {
            write-output "Provisioning has been completed for $ProjectName"
        }
        else
        {
            write-output "Provisioning failed for $ProjectName"
        }
    }
}

$return
