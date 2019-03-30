$RBName = "Create_ResourceGroups"


<#Param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectID
)#>

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

    $Conn=New-Object System.Data.SqlClient.SQLConnection
    $Conn.ConnectionString = "Server=$Server;Database=$dbName;Integrated Security=False;User Id=$uid;Password=$pw"
    $Command = New-Object System.Data.SqlClient.SqlCommand($sqlQuery,$conn)
    $Conn.Open()
    $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter $Command
    $DataSet = New-Object System.Data.DataSet
    $Adapter.Fill($DataSet)
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

#Select-AzureRmSubscription -SubscriptionId "$AzureAutomationAccountSubId"

####### Get Project ready for deployment below
#$Tags = "SELECT [ProjectTags] FROM [dbo] WHERE [DeploymentStatus] = 1"
#$ProjectTag = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $Tags
#$Project = $($ProjectTags.ProjectTag)

$ProjectRG = $null
$RGCheck = "SELECT [ResourceGroupName] FROM [dbo] WHERE [DeploymentStatus] = 1"
$ProjectRG = Invoke-SQL -Server $Server -dbName $DBname -uid $uid -pw $pw -sqlquery $RGCheck

If(![string]::IsNullOrWhitespace($ProjectRG))
{
    Write-Output "`n$($ProjectRG.Rows.Count) Project(s) ready for deployment!"

    foreach ($RG in $ProjectRG)
    {
        write-output "Launching Runbook $rbname for $($Project.ResourceGroupName)"
        $data = $($RG.ResourceGroupName)
        $Params = @{"ResourceGroupName"= $data}

        $RBJob = Start-AutomationRunbook  -Name $RBname -Parameters $params #-resourceGroupName $AzureAutomationAccountRG -AutomationAccountName $AzureAutomationAccount 
        #sleep 15
        if($RBJob)
        {
            write-output "Starting $RBname in $($RG.ResourceGroupName)"
        }
        else
        {
            write-output "Failed to start $RBName"
        }
    }
}
else
{
    "No RGs found to deploy"
}
