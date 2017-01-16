[CmdletBinding()]
param(
    $baseUri = 'http://octopus.foobar.com/',
    $reqheaders = @{"X-Octopus-ApiKey" = $env:OctopusAPIKey }, #change this if you don't have that as a env variable
    $EnvironmentName = 'Loki Dev Sandpit - Evan',
    $EnvironmentID  
)
if (!($EnvironmentID))
{
   $Environment = ((Invoke-RestMethod "$baseUri/api/environments/all" -Headers $reqheaders) | where {$_.Name -eq $EnvironmentName})
    $EnvironmentID  = $Environment.Id 
}
$Machines = Invoke-RestMethod "$baseUri/api/environments/$EnvironmentID/machines" -Headers $reqheaders
Write-Output $Machines
