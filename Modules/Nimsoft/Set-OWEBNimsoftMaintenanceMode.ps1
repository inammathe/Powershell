<#
.Synopsis
    Places ALL Contoso.com CDN monitors into maitenance mode in Nimsoft
.DESCRIPTION
    Uses the Nimsoft API Rest methods to log in, get all CDN related monitor rules and places all of those rules into maintenance mode for a specified duration
.NOTES
    Machine and user profile executing this script MUST have access to 'https://api.asm.ca.com/latest'
    Skip to region:Main for the actual body of this script
.PARAMETER username
    Nimsoft Username
.PARAMETER password
    Nimsoft Password
.PARAMETER main_start
    Maintenance window start time.
    The pattern MUST be a valid DateTime pattern - dd-MM-YYYY hh:mm:ss - E.g.'13-10-1989 23:12:12'
.PARAMETER main_dur
    Maintenance window duration
    The pattern MUST be of the following format - hh:mm:ss - E.g. '02:00:00'
#>
#Variables
$username = $OctopusParameters['username']
$password = $OctopusParameters['password']
$main_start = $OctopusParameters['main_start']
$main_dur = $OctopusParameters['main_dur']
$MonitorFolder = "Contoso OWEB's"
#create Windows user credential object
Write-Output "1. Prepare windows credentials"
$WinUserName = $OctopusParameters['WinUsername']
$WinPassword = $OctopusParameters['WinPassword'] | ConvertTo-SecureString -asPlainText -Force
$WinCred =  New-Object System.Management.Automation.PSCredential($WinUserName,$WinPassword)
#create a new powershell session with the windows credentials provided.
$lSessionName = "OctopusRunSession"
$ServerHostname = hostname
$skipCA = New-PSSessionOption -SkipCACheck
$myExistingSessions = Get-PSSession
$myExistingSessions | Where-Object {$_.Name -eq $lSessionName} | Remove-PSSession
$localSess = New-PSSession -ComputerName $ServerHostname -Credential $SqlCred -Name $lSessionName -SessionOption $skipCA
$MyRunBlock = {
    param(
        $username,
        $password,
        $main_start,
        $main_dur,
        $MonitorFolder
    )
    #region functions
    #############FUNCTIONS#############
    function New-NimsoftAPILogin {
    <#
        -username 'geoff.rich@foobar.com'
        -password 'T@tt5API01'
    #>
        param (
            [Parameter(Mandatory)][string]$username,
            [Parameter(Mandatory)][string]$password,
            [Parameter(Mandatory=$false)][string]$url = 'https://api.asm.ca.com/latest'
        )
        $arguments = "acct_login?user=$username&password=$password"
        $response = (Invoke-RestMethod "$url/$arguments").watchmouse
        if (!($response.error))
        {
            #success
            Write-Output $response.result.nkey
        }
        else
        {
            #failure
            Write-Error -Exception "`ncode: $($response.code)`nerror: $($response.error)`ninfo: $($response.info)" -Category AuthenticationError -ErrorAction Stop
        }
    }
    function Remove-NimsoftAPILogin {
        param (
            [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][string]$APIKey,
            [Parameter(Mandatory=$false)][string]$url = 'https://api.asm.ca.com/latest'
        )
        $arguments = "acct_logout?nkey=$APIKey"
    
        #Get the response from the API
        $response = (Invoke-RestMethod "$url/$arguments").watchmouse
        if (!($response.error))
        {
            #success
            Write-Output $response
        }
        else
        {
            #failure
            Write-Error -Exception "`ncode: $($response.code)`nerror: $($response.error)`ninfo: $($response.info)" -Category AuthenticationError -ErrorAction Stop
        }
    }
    function Get-NimsoftMonitor {
        param (
            [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)][string]$APIKey,
            [Parameter(Mandatory=$false)][string]$name,
            [Parameter(Mandatory=$false)][string]$folder,
            [Parameter(Mandatory=$false)][string]$url = 'https://api.asm.ca.com/latest'
        )
        $arguments = "rule_get?nkey=$APIKey"
        if($name){
            $name = [uri]::EscapeDataString($name)
            $arguments += "&name=$name"
        }
        if($folder){
            $folder = [uri]::EscapeDataString($folder)
            $arguments += "&folder=$folder"
        }
        #Get the response from the API
        $response = (Invoke-RestMethod "$url/$arguments").watchmouse
        if (!($response.error))
        {
            #success
            Write-Output $response.result.rules.rule
        }
        else
        {
            #failure
            Write-Error -Exception "`ncode: $($response.code)`nerror: $($response.error)`ninfo: $($response.info)" -Category AuthenticationError -ErrorAction Stop
        }
    }
    function Set-NimsoftMaintenanceMode {
        param (
            [Parameter(Mandatory)]
            [string]$APIKey,
            [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
            [string[]]$name,
            [Parameter(Mandatory)]
            [DateTime]$main_start,
            [Parameter(Mandatory)][ValidatePattern(“^(?:2[0-3]|[01][0-9]):[0-5][0-9]:[0-5][0-9]$")]
            [string]$main_dur,
            [Parameter(Mandatory=$false)]
            [string]$url = 'https://api.asm.ca.com/latest'
        )
        Begin {
            $main_start = $main_start -f 'yyyy-MM-dd HH:mm:ss'   
        }
        Process {
            foreach ($n in $name)
            {
                $NameEscStr = [uri]::EscapeDataString($n)
                $arguments = "rule_mod?nkey=$APIKey&name=$NameEscStr&maint_start=$main_start&maint_dur=$main_dur"
                Invoke-RestMethod "$url/$arguments" -ErrorAction Continue  
            }
        } 
    }
    #endregion
    #region Main
    #############Main#############
    #Get API key
    $APIKey = New-NimsoftAPILogin -username $username -password $password
    if($APIKey){
        #Get Monitors
        $Monitors = Get-NimsoftMonitor -APIKey $APIKey -folder $MonitorFolder 
        #Start Maitenance Mode
        if($Monitors){
            $Monitors.name | Set-NimsoftMaintenanceMode -APIKey $APIKey -main_start $main_start -main_dur $main_dur
        }
        #Remove API Key
        $APIKey | Remove-NimsoftAPILogin
    }
    #endregion
}
#Invoke the command using the created session and runblock
Invoke-Command `
    -Session $localSess `
    -ScriptBlock $MyRunBlock `
    -ArgumentList $username, $password, $main_start, $main_dur, $MonitorFolder
