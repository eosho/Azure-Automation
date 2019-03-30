$AzureAutomationAccount = "poc-automation-acct"
$AzureAutomationAccountRG = "POC-RESOURCES-RG"
$AzureAutomationAccountSubId = "f2d85cf0-b21c-4794-a259-f508c89d08c2"
$RBName = "Create_ResourceGroups"
$connectionName = "AzureRunAsConnection"

Write-Output "Checking for new projects"

try
{
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    Write-Output "Logging in to Azure...`n"
    Add-AzureRMAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
        -EnvironmentName AzureCloud | out-null
}
catch {
    if (!$servicePrincipalConnection)
    {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
    } else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

function Invoke-SQL {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Server,
        [Parameter(Mandatory=$true)]
        [string]$dbName,
        [Parameter(Mandatory=$true)]
        [string]$uid,
        [Parameter(Mandatory=$true)]
        [string]$pw,
        [Parameter(Mandatory=$true)]
        [string]$sqlQuery
    )

    $Conn=New-Object System.Data.SqlClient.SQLConnection
    $Conn.ConnectionString = "Server=$Server;Database=$dbName;Integrated Security=False;User Id=$uid;Password=$pw"
    $Command = New-Object System.Data.SqlClient.SqlCommand($sqlQuery,$conn)
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

Select-AzureRmSubscription -SubscriptionId "$AzureAutomationAccountSubId"

####### Get ProjectID and Name ready for deployment below
$ProjectValid = $null
$ProjectCheck = "SELECT [ProjectID], [ProjectName] FROM [dbo].[poc] WHERE [DeploymentStatus] = 1"
$ProjectValid = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $ProjectCheck

If(![string]::IsNullOrWhitespace($ProjectValid))
{
    Write-Output "`n$($ProjectValid.Rows.Count) Project(s) ready for deployment!"

    foreach($Project in $ProjectValid)
    {
        $Name = $($Project.ProjectName)
        $ID = $($Project.ProjectID)

        Write-Output "Getting RG info for $Name"

        $ProjectRGCheck = $null
        $RGCheck = "SELECT [ProjectRG] FROM [dbo].[poc] WHERE [ProjectName] = '$Name' AND [ProjectID] = '$ID'"
        $ProjectRGCheck = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $RGCheck

        $RG = $($ProjectRGCheck.ProjectRG)

        Write-Output "Resource Group Name - $RG"

        #$ProjectIDValid = $null
        #$ProjectIDCheck = "SELECT [ProjectID] FROM [dbo].[poc] WHERE [ProjectName] = '$($Project.ProjectName)' AND [DeploymentStatus] = 1"
        #$ProjectIDValid = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $ProjectIDCheck

        $Params = @{
            "ProjectName" = $Name
            "ResourceGroupName" = $RG
            "ProjectID" = $ID
        }

        $RBJob = Start-AutomationRunbook  -Name $RBname -Parameters $Params

        if($RBJob)
        {
            write-output "Provisioning has started for $Name with ID - $ID"
        }
        else
        {
            write-output "Provisioning failed for $Name"
        }
    }
}
else
{
    Write-Output "No projects found for provisioning at this moment!"
}
