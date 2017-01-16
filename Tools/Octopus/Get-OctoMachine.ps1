[CmdletBinding()]
param(
    $baseUri = 'http://octopus.foobar.com/',
    $reqheaders = @{"X-Octopus-ApiKey" = $env:OctopusAPIKey }, #change this if you don't have that as a env variable
    $MachineName = 'Computer40230'    
)
((Invoke-RestMethod "$baseUri/api/machines/all" -Headers $reqheaders) | where {$_.Name -eq $MachineName})
