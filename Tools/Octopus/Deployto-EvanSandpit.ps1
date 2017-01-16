param(
    $ReleaseNumber = '1.6.310-US20542', #change this
    #$ProjectName = 'Mosaic.Modules.Loki',
    $ProjectName = 'ASL.Modules.Loki',
    $baseUri = $env:OctopusURL, #change this if you don't have that as a env variable
    $reqheaders = @{"X-Octopus-ApiKey" = $env:OctopusAPIKey }, #change this if you don't have that as a env variable
    #$DeployTo = 'T19',
    $DeployTo = 'Loki Dev Sandpit - Evan' #change this    
)

# Find Environment
Write-Verbose "Finding Environment..."
$environments = Invoke-WebRequest "$baseUri/api/environments/all" -Headers $reqheaders -UseBasicParsing | ConvertFrom-Json
$environment = $environments | Where-Object {$_.Name -eq $DeployTo }
if ($environment -eq $null) {
    throw "Environment $DeployTo not found."
}
Write-Verbose "   Environment: $environment"

# Find Project
Write-Verbose "Finding Project..."
$projects = Invoke-WebRequest "$baseUri/api/projects/all" -Headers $reqheaders -UseBasicParsing | ConvertFrom-Json
$project = $projects | Where-Object {$_.Name -eq $ProjectName }
if ($project -eq $null) {
    Write-Host "Project '$ProjectName' not found."
    exit 1
}
Write-Verbose "   Project: $project"

# Check for existing release with given release number
$releaseUri = "$baseUri$($project.Links.Self)/releases/$ReleaseNumber"
try {
$release = Invoke-WebRequest $releaseUri -Headers $reqheaders -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json
} catch {
    if ($_.Exception.Response.StatusCode.Value__ -ne 404) {
        $result = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.Io.StreamReader($result);
        $responseBody = $reader.ReadToEnd();
        Write-Host "Error occurred retrieving a Release: $responseBody"
        exit 1
    }
}

#Initiate deploy. 
$deployment = @{
            ReleaseId = $release.Id
            EnvironmentId = $environment.Id
            SpecificMachineIds = $machineIDs
        } | ConvertTo-Json
$task = Invoke-WebRequest "$baseUri/api/deployments" -Method Post -Headers $reqHeaders -Body $deployment -UseBasicParsing | ConvertFrom-Json
$taskId = $task.TaskId
Write-Verbose "TaskId: $taskId"
$Completed = ""

#Wait for the deployment to finish.  Polls every 10sec
while ($Completed -ne "true")
{
    Start-Sleep -Seconds 10
    $result = Invoke-WebRequest "$baseUri/api/tasks/$taskId" -Method Get -Headers $reqHeaders -UseBasicParsing 
    $result = $result.Content | ConvertFrom-Json 
    $duration = $result.Duration
    $state = $result.State
    $statusMessage = "[$duration] '$ProjectName' deployment state: $state"
    switch ($state)
    {
        'Success' {
            Write-Host $statusMessage -ForegroundColor Green
            $Completed = "true"
        }
        'Failed' {
            Write-Host $statusMessage -ForegroundColor Red
            throw "`nDeploy failed`nErrorMessage:$($result.ErrorMessage)"
        }
        'TimedOut' {
            Write-Host $statusMessage -ForegroundColor Red
            throw "`nDeploy failed`nErrorMessage:$($result.ErrorMessage)"
        }
        'Canceled' {
            Write-Host $statusMessage -ForegroundColor Gray
            break
        }
        'Executing' {
            Write-Host $statusMessage -ForegroundColor Yellow
        }
        'Canceling' {
            Write-Host $statusMessage -ForegroundColor Gray
        }
    }
}
