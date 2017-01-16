#region set-functions
function Set-Banner
{
    [CmdletBinding()]
    param(
        [boolean]$IsActive = $false,
        [string]$Message,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [boolean]$Dismissable  = $false,
        [switch]$test
    )
    if($EndTime -le $StartTime){
        throw 'EndTime may NOT be less than or equal to StartTime'
    }

    $DebugPreference = 'Continue' 
    Write-Debug "StartTime: $StartTime"
    Write-Debug "EndTime: $EndTime"
    Write-Debug "Message: $Message"
    Write-Debug "IsActive: $IsActive"
    Write-Debug "Dismissable: $Dismissable"

    if($test){
        $JSON = Get-TestBannerConfig
    } else {
        $JSON = Get-BannerConfig    
    }
    
    $JSON = Set-IsActive  -JSON $JSON -IsActive $IsActive
    if($StartTime){$JSON = Set-StartTime  -JSON $JSON -StartTime $StartTime}
    if($EndTime){$JSON = Set-EndTime  -JSON $JSON -EndTime $EndTime}
    $JSON = Set-Message  -JSON $JSON -Message $Message
    $JSON = Set-Dismissable  -JSON $JSON -Dismissable $Dismissable
    
    if($test){
        Update-JSON -JSON $JSON -test
    } else {
        Update-JSON -JSON $JSON
    }  
}

function Set-StartTime
{
    param(
        [PSCustomObject]$JSON,
        [switch]$publish,
        [switch]$test,
        [datetime]$StartTime
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }   

    $StartTimeUTC = Get-UTCTime -LocalTime $StartTime
    [string]$JSONDateTime = Get-Date $StartTimeUTC -Format ((New-Object system.globalization.cultureinfo('en-AU')).DateTimeFormat.SortableDateTimePattern)
    $JSON.SiteMaintenanceNotificationItems | Add-Member -NotePropertyName StartTime -NotePropertyValue $JSONDateTime -Force
    
    if($publish){
        if($test){
            Update-JSON -JSON $JSON -test
        } else {
            Update-JSON -JSON $JSON
        }
    } else {
        return $JSON
    }
}

function Set-EndTime
{
    param(
        [PSCustomObject]$JSON,
        [switch]$publish,
        [switch]$test,
        [datetime]$EndTime
    ) 
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }

    $EndTimeUTC = Get-UTCTime -LocalTime $EndTime
    [string]$JSONDateTime = Get-Date $EndTimeUTC -Format ((New-Object system.globalization.cultureinfo('en-AU')).DateTimeFormat.SortableDateTimePattern)
    $JSON.SiteMaintenanceNotificationItems | Add-Member -NotePropertyName EndTime -NotePropertyValue $JSONDateTime -Force
    
    if($publish){
        if($test){
            Update-JSON -JSON $JSON -test
        } else {
            Update-JSON -JSON $JSON
        }
    } else {
        return $JSON
    }
}

function Set-Message
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$publish,
        [switch]$test,
        [string]$Message
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }
    
    if($Message.Length -gt 0){
        $JSON.SiteMaintenanceNotificationItems | Add-Member -NotePropertyName Message -NotePropertyValue $Message -Force
    }else{
        [datetime]$startTimeString = Get-LocalTime -UTCTime ([datetime]$JSON.SiteMaintenanceNotificationItems.StartTime)
        [datetime]$endTimeString = Get-LocalTime -UTCTime ([datetime]$JSON.SiteMaintenanceNotificationItems.EndTime)
        $MessageDefault = "WE'RE DOWN, BUT NOT OUT<br>We are currently undertaking scheduled maintenance and won't be available from $((get-date $startTimeString -Format F)), until $((get-date $endTimeString -Format F)) (AEST)."
        $JSON.SiteMaintenanceNotificationItems | Add-Member -NotePropertyName Message -NotePropertyValue $MessageDefault -Force
    }

    if($publish){
        if($test){
            Update-JSON -JSON $JSON -test
        } else {
            Update-JSON -JSON $JSON
        }
    } else {
        return $JSON
    }
}

function Set-IsActive
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$publish,
        [switch]$test,
        [boolean]$IsActive
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }

    $JSON.SiteMaintenanceNotificationItems | Add-Member -NotePropertyName IsActive -NotePropertyValue $IsActive -Force

    if($publish){
        if($test){
            Update-JSON -JSON $JSON -test
        } else {
            Update-JSON -JSON $JSON
        }
    } else {
        return $JSON
    }
}
function Set-Dismissable
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$publish,
        [switch]$test,
        [boolean]$Dismissable
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }

    $JSON.SiteMaintenanceNotificationItems | Add-Member -NotePropertyName Dismissable -NotePropertyValue $Dismissable -Force

    if($publish){
        if($test){
            Update-JSON -JSON $JSON -test
        } else {
            Update-JSON -JSON $JSON
        }
    } else {
        return $JSON
    }
}
#endregion

#region Get-functions
function Get-BannerSchedule
{
    param(
        [switch]$test
    )
    if($test){
        [pscustomobject][ordered]@{
            IsActive = Get-IsActive -test
            StartTime = Get-StartTime -test
            EndTime = Get-EndTime -test
            Message = Get-Message -test
        }
    } else {
        [pscustomobject][ordered]@{
            IsActive = Get-IsActive
            StartTime = Get-StartTime
            EndTime = Get-EndTime
            Message = Get-Message
        }
    }
}

function Get-BannerConfig {
    $pathEMP = '\\10.255.193.13\Contoso\data\Config\SiteMaintenanceNotificationConfig.config.json'
    $pathALB = '\\10.255.65.13\Contoso\data\Config\SiteMaintenanceNotificationConfig.config.json'
    if((Test-Path $pathEMP) -and (Test-Path $pathALB))
    {
        $JSON = (Get-Content $pathEMP) | Convertfrom-Json
    } else {
        throw "Cannot access either $pathEMP or $pathALB! Script exiting"
    }
    return $JSON  
}

function Get-StartTime
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$test
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }
    $StartTimeUTC = [datetime]$JSON.SiteMaintenanceNotificationItems.StartTime
    $StartTimeLocal = Get-LocalTime -UTCTime $StartTimeUTC
    return $StartTimeLocal
}

function Get-EndTime
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$test
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }
    $EndTimeUTC = [datetime]$JSON.SiteMaintenanceNotificationItems.EndTime
    $EndTimeLocal = Get-LocalTime -UTCTime $EndTimeUTC
    return $EndTimeLocal
}

function Get-Message
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$test
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }
    $Message = $JSON.SiteMaintenanceNotificationItems.Message
    return $Message
}

function Get-IsActive
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$test
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    } 
    $IsActive = $JSON.SiteMaintenanceNotificationItems.IsActive
    return $IsActive
}
function Get-Dismissable
{
    param(
        [PSCustomObject]$JSON = $null,
        [switch]$test
    )
    #If no JSON data is passed, use the test or production JSON
    if(!$JSON){
        if($test){
            $JSON = Get-TestBannerConfig 
        } else {
            $JSON = Get-BannerConfig 
        }
    }
    $Dismissable = $JSON.SiteMaintenanceNotificationItems.Dismissable
    return $Dismissable
}
#endregion

#region Utility functions
Function Get-LocalTime
{
     param
     (
         [datetime]$UTCTime
     )

    $strCurrentTimeZone = (Get-WmiObject win32_timezone).StandardName
    $TZ = [System.TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone)
    $LocalTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($UTCTime, $TZ)
    Return $LocalTime
}

Function Update-JSON {
    param(
        [pscustomobject]$JSON,
        [switch]$test,
        [string]$testpath = 'E:\Scripts\TestBanner\SiteMaintenanceNotificationConfig.config.json'
    )
    Test-DateDiff -JSON $JSON
    if($test){
        $JSON | ConvertTo-Json | Set-SpecialChars | Out-File "$testpath" -Force
    } else {
        $pathEMP = '\\10.255.193.13\Contoso\data\Config\'
        $pathALB = '\\10.255.65.13\Contoso\data\Config\'
        if((Test-Path $pathEMP) -and (Test-Path $pathALB))
        {
            $JSON | ConvertTo-Json | Set-SpecialChars | Out-File "$pathEMP\SiteMaintenanceNotificationConfig.config.json" -Force
            $JSON | ConvertTo-Json | Set-SpecialChars | Out-File "$pathALB\SiteMaintenanceNotificationConfig.config.json" -Force
        } else {
            throw "Cannot access either $pathEMP or $pathALB! Script exiting"
        }
    }    
}

Function Set-SpecialChars {
    param(
        [Parameter(
        Position=0, 
        ValueFromPipeline=$true)]
        $JSON
    )
    $dReplacements = @{
        '\\u003c' = '<'
        '\\u003e' = '>'
        '\\u0027' = "'"
    }
    
    foreach ($oEnumerator in $dReplacements.GetEnumerator()) {
        $JSON = $JSON -replace $oEnumerator.Key, $oEnumerator.Value
    }
    $JSON
}

Function Get-UTCTime
{
     param
     (
         [datetime]$LocalTime
     )
    $UTCTime = $LocalTime.ToUniversalTime()
    Return $UTCTime
}

Function Test-DateDiff {
    param(
        $JSON
    )
    [datetime]$StartTime = $JSON.SiteMaintenanceNotificationItems.StartTime
    [datetime]$EndTime = $JSON.SiteMaintenanceNotificationItems.EndTime
    if($EndTime -le $StartTime){
        throw "EndTime ($EndTime) may NOT be less than or equal to StartTime ($StartTime)"
    }
}
#endregion

#region Test functions
function Get-TestBannerConfig {
    param(
        [string]$path = 'E:\Scripts\TestBanner\SiteMaintenanceNotificationConfig.config.json'
    )
       
    if(Test-Path $path)
    {
        $JSON = (Get-Content $path) | Convertfrom-Json
    } else {
        throw "Cannot access $path! Script exiting"
    }
    return $JSON  
}
#endregion
