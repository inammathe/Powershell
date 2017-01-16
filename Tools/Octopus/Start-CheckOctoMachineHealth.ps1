[CmdletBinding()]
param(
    $baseUri = 'http://octopus.foobar.com/',
    $reqheaders = @{"X-Octopus-ApiKey" = $env:OctopusAPIKey }, #change this if you don't have that as a env variable
    $MachineName = 'Computer40230',
    $MachineID   
)
if (!($MachineID))
{
    $Machine = ((Invoke-RestMethod "$baseUri/api/machines/all" -Headers $reqheaders) | where {$_.Name -eq $MachineName})
    $MachineId = $Machine.Id    
}
$body = @{ 
    Name = "Health" 
    Description = "Checking health of $MachineName" 
    Arguments = @{ 
        Timeout= "00:05:00" 
        MachineIds = @($MachineId)
    } 
} | ConvertTo-Json
Invoke-RestMethod $OctopusURL/api/tasks -Method Post -Body $body -Headers $reqheaders
