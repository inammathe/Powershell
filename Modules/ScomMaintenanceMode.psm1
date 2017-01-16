Function Start-SCOMServerMaintMode {
<#
.Synopsis
    Puts Windows Computer SCOM objects into maintenance mode
.DESCRIPTION
    By using the OperationsManager module, this function places Windows Computer SCOM objects into maintenance mode 
    for a specified duration. This function has been designed with the intention that it will never 'stop' and will
    catch any generated exceptions. This is done so that this step may 'fail' during a deployment without causing
    unnecessary amounts of noise.
.EXAMPLE
    Set-ServerMaintMode -ScomServer 'contosofoomon30' -DisplayName "contosocdn01.dmz.foobar" `
    -DurationInMin 10  -Reason "PlannedHardwareMaintenance" -Comment "Server Reboot"
.EXAMPLE
    Set-ServerMaintMode -ScomServer 'contosofoomon30' -DisplayName "$((Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain)" `
    -DurationInMin 10  -Reason "PlannedHardwareMaintenance" -Comment "Server Reboot"
.PARAMETER ScomServer
    Name of the SCOM controller server. e.g. contosofoomon30
.PARAMETER ComputerName
    Name of the server to be placed into maintenance mode. Note, it is a good practice to use the FQDN for servers in different domains
.PARAMETER DurationInMin
    Duration of the maintenance window in minutes
.PARAMETER Reason
    Required SCOM field. This defines the 'category' of the maintenance window. Please see notes for possible options
.PARAMETER Comment
    Optional parameter with free text description of your choice
.NOTES 
    Valid values for the parameter 'Reason' are: 
        PlannedOther, UnplannedOther, PlannedHardwareMaintenance, UnplannedHardwareMaintenance, 
        PlannedHardwareInstallation, UnplannedHardwareInstallation, PlannedOperatingSystemReconfiguration, 
        UnplannedOperatingSystemReconfiguration, PlannedApplicationMaintenance, 
        ApplicationInstallation, ApplicationUnresponsive, ApplicationUnstable, SecurityIssue, LossOfNetworkConnectivity.
#>
    [CmdletBinding()]
    param(
        #param ScomServer
        [Parameter(Mandatory)]
        [string]$ScomServer,

        #param ComputerName
        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName,
        
        #param DurationInMin
        [Parameter(Mandatory)]
        [Int32]$DurationInMin,
        
        #param Reason
        [Parameter(Mandatory)]
        [ValidateSet('PlannedOther', 'UnplannedOther', 'PlannedHardwareMaintenance', 'UnplannedHardwareMaintenance', 
        'PlannedHardwareInstallation', 'UnplannedHardwareInstallation', 'PlannedOperatingSystemReconfiguration', 
        'UnplannedOperatingSystemReconfiguration', 'PlannedApplicationMaintenance', 
        'ApplicationInstallation', 'ApplicationUnresponsive', 'ApplicationUnstable', 'SecurityIssue', 'LossOfNetworkConnectivity')] 
        [string]$Reason,
        
        #param Comment
        [Parameter(Mandatory=$false)]
        [string]$Comment
    )   
    Begin
    {
        $ErrorsPresent = $false
        Try {
            if(!(Get-Module OperationsManager)){
                Import-Module OperationsManager -ErrorAction Stop
            }
            New-SCOMManagementGroupConnection -ComputerName $ScomServer
            $ShouldProcess = $true
        } Catch {
            Write-Warning "$($_.Exception.Message). - ScomServer:$ScomServer - Start-SCOMServerMaintMode process will be skipped" -ErrorAction Continue
            $ShouldProcess = $false
            $ErrorsPresent = $true
        }
    }
    Process
    {
        #will only run if a SCOMManagementGroupConnection can be made.
        if($ShouldProcess){
            foreach($Computer in $ComputerName) {
                $Instance = @()
                $MaintenanceMode = @()
                $objErrors = @()

                $Instance = Get-SCOMInstance -ComputerName $Computer 
                $Time = ([datetime]::Now).addminutes($DurationInMin).touniversaltime()

                if($Instance){
                    Try {
                        Start-SCOMMaintenanceMode -Instance $Instance -EndTime $Time -Comment $Comment -Reason $Reason -ErrorAction Stop

                        #refresh the instance information then get the maitenance information
                        $Instance = Get-SCOMInstance -ComputerName $Computer -ErrorAction Stop
                        $MaintenanceMode = (Get-SCOMMaintenanceMode -Instance $instance -ErrorAction Stop)
                    } Catch {
                        $objErrors += $_.Exception.Message
                        $ErrorsPresent = $true
                    }
                    
                    #return maintenance information. Return error information otherwise.
                    if($MaintenanceMode){
                        $StartTime = $MaintenanceMode[0].Starttime.ToLocalTime()
                        $ScheduledEndTime = $MaintenanceMode[0].ScheduledEndTime.ToLocalTime()
                        $Duration = [Math]::Round(((get-date $ScheduledEndTime) - (get-date $StartTime)).TotalMinutes)
                        $obj = [PSCustomObject]@{
                            ComputerName = $Computer
                            InMaintenanceMode = $Instance.InMaintenanceMode
                            StartTime = $StartTime
                            ScheduledEndTime = $ScheduledEndTime
                            'Duration(mins)' = $Duration
                            Errors = $objErrors
                        }
                        write-output $obj
                    } else {
                        $objErrors += "[Failed to get scheduled SCOMMaintenanceMode]"
                        $ErrorsPresent = $true
                        $obj = [PSCustomObject]@{
                            ComputerName = $Computer
                            InMaintenanceMode = $Instance.InMaintenanceMode
                            StartTime = $null
                            ScheduledEndTime = $null
                            'Duration(mins)' = $null
                            Errors = $objErrors
                        }
                        write-output $obj
                    }
                } else {
                    $objErrors += '[Unable to retrieve SCOM instance]'
                    $ErrorsPresent = $true
                    $obj = [PSCustomObject]@{
                        ComputerName = $Computer
                        InMaintenanceMode = $null
                        StartTime = $null
                        ScheduledEndTime = $null
                        'Duration(mins)' = $null
                        Errors = $objErrors
                    }
                    write-output $obj
                }
            }
        }
    }
    End 
    {
        if($ErrorsPresent) {
            Write-Warning 'Start-ServerMaintMode Completed with errors' 
        } 
    }
}

Function Set-GroupMaintMode {
<#
.Synopsis
    Puts a group of servers in SCOM into maintenance mode.
.DESCRIPTION
    By using the OperationsManager module, this function places a SCOM group of servers into maintenance mode 
    for a specified duration.
.EXAMPLE
    Set-GroupMaintMode -ScomServer 'contosofoomon30' -GroupDisplayName "Contoso: APS Digital ALL Servers" `
    -DurationInMin 10  -Reason "PlannedHardwareMaintenance" -Comment "Server Reboot"
.EXAMPLE
    Set-GroupMaintMode -ScomServer 'contosofoomon30' -GroupDisplayName "Contoso: APS Digital ALL Servers" `
    -DurationInMin 10  -Reason "PlannedHardwareMaintenance" -Comment "Server Reboot"
.PARAMETER ScomServer
    Name of the SCOM controller server. e.g. contosofoomon30
.PARAMETER GroupDisplayName
    Name of the group to be placed into maintenance mode. 
.PARAMETER DurationInMin
    Duration of the maintenance window in minutes
.PARAMETER Reason
    Required SCOM field. This defines the 'category' of the maintenance window. Please see notes for possible options
.PARAMETER Comment
    Optional parameter with free text description of your choice
.NOTES 
    Valid values for the parameter 'Reason' are: 
        PlannedOther, UnplannedOther, PlannedHardwareMaintenance, UnplannedHardwareMaintenance, 
        PlannedHardwareInstallation, UnplannedHardwareInstallation, PlannedOperatingSystemReconfiguration, 
        UnplannedOperatingSystemReconfiguration, PlannedApplicationMaintenance, 
        ApplicationInstallation, ApplicationUnresponsive, ApplicationUnstable, SecurityIssue, LossOfNetworkConnectivity.
#>
    [CmdletBinding()]
    param(
        #param DisplayName
        [Parameter(Mandatory)]
        [string]$ScomServer,

        #param GroupDisplayName
        [Parameter(Mandatory,ValueFromPipeline)]
        [string]$GroupDisplayName,
        
        #param DurationInMin
        [Parameter(Mandatory)]
        [Int32]$DurationInMin,
        
        #param Reason
        [Parameter(Mandatory)]
        [ValidateSet('PlannedOther', 'UnplannedOther', 'PlannedHardwareMaintenance', 'UnplannedHardwareMaintenance', 
        'PlannedHardwareInstallation', 'UnplannedHardwareInstallation', 'PlannedOperatingSystemReconfiguration', 
        'UnplannedOperatingSystemReconfiguration', 'PlannedApplicationMaintenance', 
        'ApplicationInstallation', 'ApplicationUnresponsive', 'ApplicationUnstable', 'SecurityIssue', 'LossOfNetworkConnectivity')] 
        [string]$Reason,
        
        #param Comment
        [Parameter(Mandatory=$false)]
        [string]$Comment
    )
    Begin
    {
        Try {
            if(!(Get-Module OperationsManager)){
                Import-Module OperationsManager
            }
            New-SCOMManagementGroupConnection -ComputerName $ScomServer
        } Catch {
            throw $_.Exception.Message
        }
    }
    Process
    {
        Try {
            $SCOMGroup = (Get-ScomGroup -DisplayName  $GroupDisplayName)
        } Catch {
            throw $_.Exception.Message
        }

        if($SCOMGroup){
            ForEach ($Group in $SCOMGroup)
            {
                If ($Group.InMaintenanceMode -eq $false)
                {
                    $Group.ScheduleMaintenanceMode([datetime]::Now.touniversaltime(), `
                    ([datetime]::Now).addminutes($DurationInMin).touniversaltime(), `
                     "$Reason", "$Comment" , "Recursive")
                 }
            }
        } else {
            throw "No results returned for the SCOM group matching the DisplayName $GroupDisplayName"
        }
    }
    End
    {
        Write-Output "$GroupDisplayName placed into maitenance mode for $DurationInMin minutes"
    }
}

Function Get-SCOMInstance {
    param(
        [string]$ComputerName
    )
    Try {
    (Get-SCOMClassInstance -Name $ComputerName -ErrorAction stop) | 
        Where-Object {$_.FullName -like 'Microsoft.Windows.Computer*'}
    } Catch {
        Write-Output $Error[0]
    }
}
