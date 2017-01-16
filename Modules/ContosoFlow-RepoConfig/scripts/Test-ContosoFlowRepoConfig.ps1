<#
.SYNOPSIS
Tests a ContosoFlow repository and reports on the status of its configuration
.DESCRIPTION
Uses the ContosoFlow API (and optional extra, TeamCity API) to query the status of a ContosoFlow repository configuration.
.PARAMETER ContosoFlowObj
.PARAMETER credential
.PARAMETER username
.PARAMETER password
.PARAMETER StatusChecksRequired
.EXAMPLE
PS C:\> Test-ContosoFlowRepoConfig
.NOTES
NAME        :  Test-ContosoFlowRepoConfig
VERSION     :  1.0   
LAST UPDATED:  18/08/2016
AUTHOR      :  foobar\evan.lock
Learn more about PowerShell:
http://jdhitsolutions.com/blog/essential-powershell-resources/
  ****************************************************************
  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
  ****************************************************************
.LINK
.INPUTS
.OUTPUTS
#>
function Test-ContosoFlowRepoConfig {
    Param(
        $ContosoFlowObj,
        $credential,
        $username,
        $password,
        $StatusChecksRequired = ('rally','testing','code-review','MandatoryWorkItem')
    )
    Begin{
        $UseTC = $false
        if(-not($credential)){
            if($username -and $password){
                $credential = Set-TCCredential -username $username -password $password
                $UseTC = $true
            }  
        } 
    }
    Process {
        $errors = @()
    
        #Enabled check
        $Enabled = $ContosoFlowObj.settings.enabled
        if (!($Enabled))
        {
            $Enabled = $false
            $errors += "[Enabled check failed. Enabled=False]"
        }
    
        #Status Checks
        $StatusChecks = $ContosoFlowObj.settings.statuschecks
        if($StatusChecks)
        {
            $StatusChecksPresent = $true
            #Name Check
            $StatusChecksRequired | ForEach-Object {
                if($StatusChecks.name -notcontains $_)
                {
                    $errors += "[Status name check failed. Missing $_]"
                }  
            }
        } else {
            $StatusChecksPresent = $false
            $errors += "[Status Name check failed. No status checks present]"
        }
        #BranchProtection enable check
        $BPEnabled = $ContosoFlowObj.settings.GitHub.BranchProtectionEnabled        
        if (!($ContosoFlowObj.settings.GitHub.BranchProtectionEnabled))
        {
            $BPEnabled = $false
            $errors += "[BranchProtection enable check failed. BranchProtectionEnabled=$false]"
        }
        #BranchProtection regex check
        $BPRegex = $ContosoFlowObj.settings.GitHub.BranchProtectionRegex
        if(-not($BPRegex) -or $BPRegex -ne '^master$|^release[-\/]\S+$')
        {
            $errors += "[BranchProtection regex check failed. BranchProtectionRegex=$($BPRegex)]" 
        }
        #Octopus Deploy Project ID check
        $ProjectID = $ContosoFlowObj.settings.Octopus.ProjectId
        if(-not($ProjectID))
        {
            $errors += "[Octopus.ProjectId check failed. ProjectId not present]"
        }
        #TeamCity Build Config ID check
        $TCBuildID = $ContosoFlowObj.settings.TeamCity.BuildConfigId
        if(-not($TCBuildID))
        {
            $errors += "[TeamCity.BuildConfigId check failed. Build Config ID not present]"
        }
        if($errors){
            $healthy = $false
        } else {
            $healthy = $true
        }
        #TeamCity Feature Config
        if($UseTC){
            $Features = ($ContosoFlowObj.name | Get-ID -TeamCity | Get-TCBuildConfig -credential $credential).buildtype.Features.feature.type
        }
        [pscustomobject]@{
            Healthy = $healthy
            Name = $ContosoFlowObj.name
            Enabled = $enabled
            StatusChecksPresent = $StatusChecksPresent
            BranchProtectionEnabled = $BPEnabled
            BranchProtectionRegex = $ContosoFlowObj.settings.GitHub.BranchProtectionRegex
            Octopus_ProjectID = $ContosoFlowObj.settings.Octopus.ProjectId
            TeamCity_Build_ConfigID = $ContosoFlowObj.settings.TeamCity.BuildConfigId
            Features = $Features
            Errors = $errors
            StatusChecks = $ContosoFlowObj.settings.StatusChecks
        }
    }
}
