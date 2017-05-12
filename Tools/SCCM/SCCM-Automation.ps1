<#
.SYNOPSIS
    Creates and deploys a SCCM package
.DESCRIPTION
    Uses System Center 2012 Configuration Manager Cmdlets to create a package with 3 programs (Per-system unattended, Per-system attended and Uninstall) for a specified msi.
    It will then create a new deployment schedule to deploy the package to a specified collection.
    If no deployment time is speicifed, it will default to -
        . available 1 from the current time 
        . deployed 2 hours from the current time.
.PARAMETER PackageName
    The desired name of the SCCM Package. e.g. contosoCis Support Application
    The version of the package being deployed will automatically be appended to this name to ensure unquiqueness and enable multiple deploys of the same package.
.PARAMETER Version
    SCCM package version.
.PARAMETER Path
    Share or directory path to where different versions of the application install msi's are stored
    e.g. '\\contosogroup.com\shared\ConfigMgr\Applications\contosoGroup\contosoCIS\'
.PARAMETER SCCMPath
    Path within the SCCM software Library where the package will be stored
    e.g. '.\Packages\contoso Group\contoso Group\contosoCIS'
.PARAMETER SCCMSite
    SCCM site servername. This is used to query the content status after distribution.
.PARAMETER Process
    Process name of the application once it is installed an running e.g. 'contosocis'
    This is required for the Uninstall program.
.PARAMETER AppName
    Application name of the application once it is installed an running e.g. 'contosoCis Support Application'
.PARAMETER Collection
    SCCM device collection that the package will be deployed to e.g. contoso Group Norse contosoCis INSTALL
.PARAMETER SiteCode
    SCCM site code.
.PARAMETER DistributionPoints
    SCCM Distribution Points that the package will be distributed to. 
    A string of servers seperated by commas ','
.PARAMETER ValidationTimeOut
    Sets how long in minutes the validation process should go for before giving up.
    You may wish to increase or descrease this value depending on the size of the application package being distributed (longer for bigger)
.PARAMETER DeployTime
    The desired time for deployment. Must be in a recognisable datetime format. e.g. '20/04/2017 05:00'
    If unspecified, the deploy time will be set to be available in 1 hour and then automatically deployed in 2 hours
.PARAMETER ComputerName
    Name of the server that will be communicating with the SCCM host. This server requires a correctly installed System Center 2012 Configuration Manager Cmdlet Library. 
    If unspecified, it will default to the name of the host running the script.
.PARAMETER Account_Username
    Username of the account that will access the System Center 2012 Configuration Manager Cmdlet Library
    Appropriate privileges are required to access SCCM. e.g. DG-SCCMAdmins
.PARAMETER Account_Password
    Password of the account that will access the System Center 2012 Configuration Manager Cmdlet Library
    Appropriate privileges are required to access SCCM. e.g. DG-SCCMAdmins
.EXAMPLE
    PS C:\> . .\SCCM-Automation.ps1 `
                -PackageName 'contosoCis Support Application' `
                -Version '1.01.256.4' `
                -Path '\\contosogroup.com\shared\ConfigMgr\Applications\contosoGroup\contosoCIS\' `
                -SCCMPath '.\Package\Contoso Group\contoso Group\contosoCIS' `
                -SCCMSite 'NPRDC1SSDS02.contosononprod' `
                -Process 'contosocis' `
                -AppName 'contosoCis Support Application' `
                -Collection 'contoso Group Norse contosoCis INSTALL' `
                -SiteCode 'TG1' `
                -DistributionPoints 'server2ssds02.contosogroup.com,serverarprdfil11.contosogroup.com,serverlprdsds02.contosogroup.com,serverhobprdsds02.contosogroup.com,servermelprdsds02.contosogroup.com,serversopprdsds02.contosogroup.com' `
                -ValidationTimeOut '20' `
                -DeployTime '21/04/2017 04:00' `
                -Account_Username 'scserverCCMDeployUserr' `
                -Account_Password 'supersecretpassword'

    This will schedule a deployment for contosoCis at 21/04/2017 04:00. Because no ComputerName is specified, the $env:COMPUTERNAME name will be used instead.
.INPUTS
    None
.OUTPUTS
    None
.NOTES
    Version:        1.23
    Author:         Evan Lock
    Creation Date:  20/04/2017
    
    This script was designed with Octopus Deploy in mind as a step template. However, it will function outside of Octopus.
    To install SCCM on a host, add it to the following group: 'W7-App-Microsoft Configuration Manager Console 2012'
    You will also have to have opened the SCCM console at least once on the server using the modules as the user you intend to use.
#>

param(
    [string]$PackageName,
    [string]$Version,
    [string]$Path,
    [string]$SCCMPath,
    [string]$SCCMSite,
    [string]$Process,
    [string]$AppName,
    [string]$Collection,
    [string]$SiteCode,
    [string[]]$DistributionPoints,
    [string]$ValidationTimeOut,
    [string]$DeployTime,
    [string]$ComputerName,
    [string]$Account_Username,
    [string]$Account_Password
) 

$ErrorActionPreference = "Stop" 

function Get-Param($Name, [switch]$Required, $Default) {
    if ($OctopusParameters) {
        $result = $OctopusParameters[$Name]
    }

    if (!$result) {
        $variable = Get-Variable $Name -EA SilentlyContinue   
        if ($variable) {
            $result = $variable.Value
        }
    }
    if (!$result) {
        if ($Required) {
            throw "Missing parameter value $Name"
        } else {
            $result = $Default
        }
    }

    Write-Output $result
}

# More custom functions would go here
$MyRunBlock = {
    param(
        [PSCustomObject]$SCCMObject
    )

    $ErrorActionPreference = 'Stop'

    # Check if user is a local admin
    Write-Host "7.) Checking that the user is a Administrator" 
    If (!(New-Object Security.Principal.WindowsPrincipal ([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Throw "Needs to be run as a user with Administrator privileges"
    }

    # Test the ConfigMgr env variable
    Write-Host "8.) Testing ConfigMgr env variable" 
    If (!($Env:SMS_ADMIN_UI_PATH)) {
        Throw "Missing SMS_ADMIN_UI_PATH environment variable. Ensure SCCM is installed correctly"
    }

    # Get msi details
    Write-Host "9.) Getting msi details" 
    $sourcePath = Join-Path $SCCMObject.Path $SCCMObject.Version
    if (!(Test-Path $sourcePath)) {
        Throw "Cannot access: $sourcePath"
    }
    $program = (Get-ChildItem $sourcePath | Where-Object {$_.extension -eq ".msi"})
    $programMSI = $program.Name
    $programSize = [math]::truncate($program.Length /1MB)

    # Load the module
    Write-Host "10.) Loading the SCCM module" 
    $cmModulePath = $Env:SMS_ADMIN_UI_PATH.Substring(0,$Env:SMS_ADMIN_UI_PATH.Length-5) + "\ConfigurationManager.psd1"
    If (!(Test-Path $cmModulePath)) {
        Throw "Cannot access $($cmModulePath)"
    }
    Import-Module $cmModulePath
    Set-Location "$(Get-PSDrive -PSProvider CMSite):\" #Will fail if you haven't opened the sccm console on the target machine as the user this is running as

    # Check if the package already exists
    Write-Host "11.) Creating the package and programs" 
    $SCCMPackage = Get-CMPackage -Name $SCCMObject.PackageName -WarningAction SilentlyContinue -ErrorAction SilentlyContinue

    # Create the package and programs if package does not exist.
    Write-Host "`tChecking if package $($SCCMObject.PackageName) already exists..."
    if (!$SCCMPackage) 
    {
        Write-Host "`tPackage $($SCCMObject.PackageName) does not exist. Creating package and programs"
        New-CMPackage -Name $SCCMObject.PackageName -Path $sourcePath -Version $SCCMObject.Version -Manufacturer "contoso Group" -WarningAction SilentlyContinue | Out-Null
        New-CMProgram -PackageName $SCCMObject.PackageName -StandardProgramName "Per-system unattended" -CommandLine "msiexec.exe ALLUSERS=2 /m MSIHWXHJ /i $programMSI" -programruntype WhetherorNotUserisLoggedOn -runmode RunWithAdministrativeRights -UserInteraction $false -DiskSpaceRequirement $programSize -DiskSpaceUnit MB -Duration 20 -WarningAction SilentlyContinue  | Out-Null
        New-CMProgram -PackageName $SCCMObject.PackageName -StandardProgramName "Per-system uninstall" -CommandLine "msiexec.exe /q /m MSIHWXHJ /x $programMSI" -programruntype WhetherorNotUserisLoggedOn -runmode RunWithAdministrativeRights -UserInteraction $false -WarningAction SilentlyContinue | Out-Null
        New-CMProgram -PackageName $SCCMObject.PackageName -StandardProgramName "Uninstall" -CommandLine "powershell.exe -ExecutionPolicy Bypass .\Uninstall.ps1 `"$($SCCMObject.Process)`" `"$($SCCMObject.AppName)`"" -programruntype WhetherorNotUserisLoggedOn -runmode RunWithAdministrativeRights -UserInteraction $false -WarningAction SilentlyContinue | Out-Null
        
        $SCCMPackage = Get-CMPackage -Name $SCCMObject.PackageName -WarningAction SilentlyContinue

        #Add the Uninstall script as a dependent program of unattended
        Write-Host "`tAdding uninstall program dependency"
        $UnattendedProgram = Get-CMProgram -PackageName $SCCMObject.PackageName -ProgramName 'Per-system unattended' -WarningAction SilentlyContinue 
        $UnattendedProgram.DependentProgram =  "$($UnattendedProgram.PackageID);;Uninstall" #Sets the run another program first
        $UnattendedProgram.ProgramFlags = 2282792064 #Ticks the 'Always run this program first' property
        $UnattendedProgram.Put()

        # Move the package to the location in the Folders within SCCM
        Write-Host "12.) Moving the package to the SCCMPath: $($SCCMObject.SCCMPath)" 
        Move-CMObject -FolderPath "$($SCCMObject.SCCMPath)" -inputobject $SCCMPackage -WarningAction SilentlyContinue 
        $SCCMPackage = Get-CMPackage -Name $SCCMObject.PackageName -WarningAction SilentlyContinue #refresh package object with new location -WarningAction SilentlyContinue
    }
    else
    {
        Write-Host "`tPackage already exists. Skipping Package Creation (11.) and Package Sccm Folder Move (12.)"
    }

    # Distribute the Content
    Write-Host "13.) Distributing content to DistributionPoints"
    foreach ($distributionPoint in $SCCMObject.DistributionPoints) 
    {
        Write-Verbose "$($SCCMPackage.PackageID) to $distributionPoint"
        Start-CMContentDistribution -PackageID $SCCMPackage.PackageID -DistributionPointName $distributionPoint -WarningAction SilentlyContinue
    }

    # Increment source version - issues experienced when SourceVersion = 1
    Write-Host "14.) Checking package source version"
    if ($SCCMPackage.SourceVersion -lt 2) {
        Write-Host "`tIncrementing package source version - SourceVersion:$($SCCMPackage.SourceVersion) + 1"
        Update-CMDistributionPoint -PackageID $SCCMPackage.PackageID -WarningAction SilentlyContinue    
    }   
    else
    {
        Write-Host "`tPackage source version already incremented"
    }
  
    # Validate the Content - This may take some time depending on the size of the application being distributed
    Write-Host "15.) Validating content distribution"
    $StartValidationTime = Get-Date 
    [System.Collections.ArrayList]$DPToValidate = $SCCMObject.DistributionPoints #required due to $SCCMObject.DistributionPoints being a fixed size array
    $ValidatedDPs = @()
    $ValidationAttempts = 1
    while ($ValidatedDPs.Count -lt $SCCMObject.DistributionPoints.Count) #Start while loop
    {
        Write-Host "`Validation attempt number: `t$ValidationAttempts`nValidation time remaining: `t$([MATH]::TRUNCATE((New-TimeSpan -Start (get-date) -End (Get-Date $StartValidationTime).AddMinutes($SCCMObject.ValidationTimeOut)).Totalminutes)) minutes`n"
        
        # Get package state information - this wmi object query is why the account running this requires such high privileges (DG-SCCMAdmins)
        $packageStatus = Get-WmiObject -ComputerName $SCCMObject.SCCMSite -Namespace "Root\SMS\Site_$($SCCMObject.SiteCode)" -Class SMS_PackageStatusDistPointsSummarizer | 
                Where-Object "PackageID" -EQ  $SCCMPackage.PackageID | 
                Select-Object SourceNALPath, PackageID, SourceVersion, State, ServerNALPath

        # Iterate through distribution points still yet to be validated
        if ($packageStatus) 
        {
            foreach ($DP in $DPToValidate) {
                #Select the packageStatus object that relates to the distribution point (using ServerNALPath)
                $contentDPStatus = $packageStatus | Where-Object {(($_.ServerNALPath).Split('\\', [System.StringSplitOptions]::RemoveEmptyEntries) | Select-Object -last 1) -eq $DP}
                
                if($contentDPStatus) 
                {
                    # see https://msdn.microsoft.com/en-us/library/hh442764.aspx
                    switch ($contentDPStatus.State) {
                        0 { $ValidatedDPs += $DP;  Write-Host "`t$DP - INSTALLED" }
                        1 {  Write-Host "`t$DP - INSTALL_PENDING" }
                        2 {  Write-Host "`t$DP - INSTALL_RETRYING" }
                        3 { Throw "$DP - INSTALL_FAILED" }
                        4 {  Write-Host "`t$DP - REMOVAL_PENDING" }
                        5 {  Write-Host "`t$DP - REMOVAL_RETRYING" }
                        6 {  Write-Host "`t$DP - REMOVAL_FAILED" }
                        7 {  Write-Host "`t$DP - CONTENT_UPDATING" }
                        8 {  Write-Host "`t$DP - CONTENT_MONITORING" }
                        default {  Write-Host "$DP - unexpected state: $($contentDPStatus.State)" }
                    }
                }
                else
                {
                    Write-Warning "No status object found matching Distribution Point - $DP"
                }
            }
        }
        else 
        {
            Write-Warning "No package status found matching Package: ID - $($SCCMPackage.PackageID)`tName - $($SCCMObject.PackageName)"    
        }
        
        # Remove the validated distribution points from the list of DPs requiring validation
        foreach ($ValidatedDP in $ValidatedDPs) {
            if($DPToValidate -contains $ValidatedDP)
            {
                Write-Host "`t$ValidatedDP - content validated"
                $DPToValidate.Remove($ValidatedDP)
            }
        }
        
        # Check how long it has been since validation started
        if(((Get-Date) - $StartValidationTime).TotalMinutes -ge $SCCMObject.ValidationTimeOut) 
        {
            Throw "Validation timeout value reached ($($SCCMObject.ValidationTimeOut) minutes)"
        }

        $ValidationAttempts++

        #Only sleep if there validation remaining i.e. while loop needs to loop again.
        if($ValidatedDPs.Count -lt $SCCMObject.DistributionPoints.Count)
        {
            Write-Host "`tDistribution points remaining: $DPToValidate`tCount: $($ValidatedDPs.Count) of $($SCCMObject.DistributionPoints.Count) validated"
            Start-Sleep -Seconds 60
        }
    } #End while loop
    Write-Host "`tDistribution point validation complete" 

    # Remove old deployments
    Write-Host "16.) Removing old deployments of $($SCCMObject.PackageName) to collection $($SCCMObject.Collection)" 
    $CMDeployments = Get-CMDeployment -CollectionName $SCCMObject.Collection -WarningAction SilentlyContinue | 
        Where-Object {$_.PackageID -eq $SCCMPackage.PackageID}

    if ($CMDeployments)
    {
        $CMDeployments | Remove-CMDeployment -Force -WarningAction SilentlyContinue
    }

    # Create the CMSchedule object
    Write-Host "17.) Creating the New-CMSchedule for: $($SCCMObject.DeploySchedule.requireTime)" 
    $CMSchedule = New-CMSchedule -Start $SCCMObject.DeploySchedule.requireTime -Nonrecurring -WarningAction SilentlyContinue

    # Determine how many packages need to be queried
    Write-Host "18.) Determining how many packages need to be queried"
    $PkgCount = (Get-WmiObject -ComputerName $SCCMObject.SCCMSite -Namespace "Root\SMS\Site_$($SCCMObject.SiteCode)" -Query "SELECT COUNT(*) FROM SMS_Package AS pkg INNER JOIN SMS_DistributionPoint AS srv ON pkg.PackageID = srv.PackageID WHERE pkg.ActionInProgress!=3 AND pkg.PackageType=0").Count
    Write-Host "`tResult: $PkgCount"

    # Get the query maximum
    Write-Host "19.) Getting the current query maximum"
    $QueryMaximum =  Get-CMQueryResultMaximum -WarningAction SilentlyContinue
    Write-Host "`tResult: $QueryMaximum"

    # Raise the maximum if required
    Write-Host "20.) Raising the maximum if required"
    if ($QueryMaximum -lt $PkgCount) {
        Set-CMQueryResultMaximum -Maximum $PkgCount -WarningAction SilentlyContinue
        Write-Host "`tCMQueryResultMaximum raised to: $PkgCount"
    }

    # Deploy Required package - if CMQueryResultMaximum was lower than PkCount, this would likely fail.
    Write-Host "21.) Scheduling the deployment..." 
    Start-CMPackageDeployment -StandardProgram -CollectionName $SCCMObject.Collection -PackageName $SCCMObject.PackageName -ProgramName "Per-system unattended" -DeployPurpose Required -AllowSharedContent $true `
    -DeploymentAvailableDateTime $SCCMObject.DeploySchedule.availableTime -Schedule $CMSchedule -RerunBehavior RerunIfFailedPreviousAttempt -SoftwareInstallation $True `
    -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally -SlowNetworkOption DownloadContentFromDistributionPointAndLocally -WarningAction SilentlyContinue

    Write-Host "-----SCCM deployment successfully scheduled-----"
    Write-Host "Target collection: `t$($SCCMObject.Collection)"
    Write-Host "Package to be deployed: `t$($SCCMObject.PackageName)"
    Write-Host "Scheduled available time: `t$($SCCMObject.DeploySchedule.availableTime)"
    Write-Host "Scheduled required time: `t$($SCCMObject.DeploySchedule.requireTime)"
}

function Get-DeploySchedule
{
    Param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $DeployTime
    )
    try 
    {
        if ($DeployTime.GetType().Name -eq 'String') #if true, this parameter must have been passed in manually or via Octopus
        {
            #Check if the deploy time was set to in the past.
            if ((get-date $DeployTime) -lt (Get-Date).AddMinutes(-1)) {
                Throw "Unable to schedule a deployment in the past. Please set the deploytime to a later datetime"
            }
            Write-Verbose "Configuring specified deploy time - $DeployTime"
            $DeployTime = Get-Date $DeployTime
            $availableTime = get-date ($DeployTime) -Format "yyyy/MM/dd HH:mm"
            $requireTime = get-date ($DeployTime).AddMinutes(10) -Format "yyyy/MM/dd HH:mm"
        }
        elseif ($DeployTime.Gettype().name -eq 'DateTime')
        {
            Write-Verbose "Configuring default deploy time - $DeployTime + 2 hours"
            $availableTime = get-date ($DeployTime).AddHours(1) -Format "yyyy/MM/dd HH:mm"
            $requireTime = get-date ($DeployTime).AddHours(2) -Format "yyyy/MM/dd HH:mm"
        }
        else 
        {
            Throw "Invalid DeployTime variable type: `n`t$($DeployTime.Gettype())"    
        }

        $DeploySchedule = [pscustomobject]@{
            availableTime = $availableTime
            requireTime = $requireTime
        }  
        
        Write-Output $DeploySchedule
    }
    catch 
    {
        #Most likely exception here will be the string to datetime casting/conversion.
        throw $error[0].Exception.Message 
    }    
}

& {
    param(
        [string]$PackageName,
        [string]$Version,
        [string]$Path,
        [string]$SCCMPath,
        [string]$SCCMSite,
        [string]$Process,
        [string]$AppName,
        [string]$Collection,
        [string]$SiteCode,
        [string[]]$DistributionPoints,
        [string]$ValidationTimeOut,
        $DeployTime,
        [string]$ComputerName,
        [string]$Account_Username,
        [string]$Account_Password
    ) 
    
    Write-Host "1.) Configuring the deploy schedule"
    $DeploySchedule = Get-DeploySchedule -DeployTime $DeployTime

    Write-Host "2.) Configuring the distribution points"
    $DistributionPoints = $DistributionPoints.Split(',')

    Write-Host "3.) Configuring the package name"
    $PackageName =  "$PackageName - $(Get-Date -Format "ddMMyy")" #ensures package name uniqueness between deploys

    Write-Host "4.) Creating the SCCMObject"
    $SCCMObject = [PSCustomObject]@{
        PackageName = $PackageName
        Version = $Version
        Path = $Path
        SCCMPath = $SCCMPath
        SCCMSite = $SCCMSite
        Process = $Process
        AppName = $AppName
        Collection = $Collection
        SiteCode = $SiteCode
        DistributionPoints = @($DistributionPoints)
        ValidationTimeOut = [int]$ValidationTimeOut
        DeploySchedule = $DeploySchedule
        ComputerName = $ComputerName
    }
    $SCCMObject | Format-List

    Write-Host "5.) Configuring credentials and local session"

    #create the user credential object
    Write-Host "`tCreating the user credential object"
    $SecurePassword = $Account_Password | ConvertTo-SecureString -asPlainText -Force
    $Credentials =  New-Object System.Management.Automation.PSCredential($Account_Username,$SecurePassword)
  
    #Remove any current sessions with the name we want.
    Write-Host "`tRemoving any current sessions with the name we want"
    $lSessionName = "OctopusRun"
    $myExistingSessions = Get-PSSession
    $myExistingSessions | Where-Object {$_.Name -eq $lSessionName} | Remove-PSSession

    #Format the hostname and configure some options
    Write-Host "`tFormatting the hostname and configuring PSSession options"
    $ComputerName = ($ComputerName.Split("`\")[0].Split(":")[0])
    $skipCA = New-PSSessionOption -SkipCACheck

    #Register a new PSSession configuration - this gets around the 'double hop' authentication issue
    Write-Host "`tRegistering a new PSSession configuration - this gets around the 'double hop' authentication issue"
    $PSConfigName = 'OctopusSession'
    Register-PSSessionConfiguration -Name $PSConfigName -SessionType DefaultRemoteShell -AccessMode Remote -RunAsCredential $Credentials -Force -WarningAction SilentlyContinue | Out-Null

    #create a new powershell session with the windows credentials provided.
    Write-Host "`tCreating a new powershell session with the windows credentials provided"
    $localSess = New-PSSession -ComputerName $ComputerName -Credential $Credentials -Name $lSessionName -SessionOption $skipCA -ConfigurationName $PSConfigName

    Write-Output "6.) Running the script block in new PS Session: $lSessionName"

    Invoke-Command `
        -Session $localSess `
        -ScriptBlock $MyRunBlock `
        -argumentlist $SCCMObject

    Write-Host "--------------------Complete--------------------"
} `
(Get-Param -Name 'PackageName' -Required) `
(Get-Param -Name 'Version' -Required) `
(Get-Param -Name 'Path' -Required) `
(Get-Param -Name 'SCCMPath' -Required) `
(Get-Param -Name 'SCCMSite' -Required) `
(Get-Param -Name 'Process' -Required) `
(Get-Param -Name 'AppName' -Required) `
(Get-Param -Name 'Collection' -Required) `
(Get-Param -Name 'SiteCode' -Required) `
(Get-Param -Name 'DistributionPoints' -Required) `
(Get-Param -Name 'ValidationTimeOut' -Required) `
(Get-Param -Name 'DeployTime' -Default (Get-Date)) `
(Get-Param -Name 'ComputerName' -Default ($env:COMPUTERNAME)) `
(Get-Param -Name 'Account_Username' -Required) `
(Get-Param -Name 'Account_Password' -Required) `
($MyRunBlock)