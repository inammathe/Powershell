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
