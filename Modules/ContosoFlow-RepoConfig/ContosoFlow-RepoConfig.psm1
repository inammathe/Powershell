<#
.Synopsis
   Can query and change the configuration ContosoFlow repositories 
.DESCRIPTION
   Uses the ContosoFlow and TeamCity API to perform the following actions:
        a.) Produce a status report/object on the repo configuration of 1 or more repositories
        b.) Retrieve TeamCity build configuration
        c.) Restore 1 more ContosoFlow repositories from a JSON template
.EXAMPLE
   Get-ContosoFlowRepoStatus -Repos $Repos | 
   Where-Object {-not($_.healthy)} | 
   Select-Object -Property Name | 
   Restore-ContosoFlowConfig -JSONTemplate "E:\Scripts\API-CheatSheet\ContosoFlow\ContosoFlowConfig_Template.JSON"

   This command will query a list of repositories and their configuration and determine which are 'unhealthy'. These unhealthy repos are then restored using a JSON file template.
.EXAMPLE
   Get-ContosoFlowRepoStatus -Repos $Repos -credential $credential

   Specifying credentials will alow use of the TeamCity API (not required)
.EXAMPLE
   $Names | Get-ID -TeamCity | Get-TCBuildConfig -credential $credential

   By passing in a string array of repo names, this will return a list of objects containing team city build configuration information.
.NOTES
   NAME        :  ContosoFlow-RepoConfig.psm1
   VERSION     :  1.0   
   LAST UPDATED:  16/08/2016
   AUTHOR      :  foobar\Evan.Lock
#>

function Restore-ContosoFlowConfig {
<#
.SYNOPSIS
Restores a ContosoFlow repo configuration to any given state
.DESCRIPTION
Uses the ContosoFlow api to POST a JSON body that has been specified as a parameter to the function to any number of ContosoFlow Repositories
.PARAMETER RepoNames
Names of the repositories to be restored
.PARAMETER JSONTemplate
Location of the JSON file to be used as a template for ContosoFlow repo configuration
.EXAMPLE
PS C:\> Restore-ContosoFlowConfig -JSONTemplate "E:\Scripts\API-CheatSheet\ContosoFlow\ContosoFlowConfig_Template.JSON"

.NOTES
NAME        :  Restore-ContosoFlowConfig
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
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RepoNames,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$JSONTemplate        
    )
    Begin 
    {
        Try{Get-Content $JSONTemplate | ConvertFrom-Json -ErrorAction Stop}
        Catch{throw "Unable to validate JSON data in $JSONTemplate`n$($Error[0])"}
    }
    Process 
    {
        foreach ($RepoName in $RepoNames)
        {
            $JSONObj = Get-Content $JSONTemplate | ConvertFrom-Json
            $JSONObj.TeamCity.BuildConfigId = Get-ID -name $RepoName -TeamCity
            $JSONObj.Octopus.ProjectId = Get-ID -name $RepoName -Octopus
            $JSON = $JSONObj | ConvertTo-Json
            Invoke-RestMethod -Uri "http://api.Contosoflow.foobar.com/settings/foobar/$RepoName/" -Method Post -Body $JSON -ContentType "application/json;charset=UTF-8"     
        }
    }
}

function Test-ContosoFlowRepoConfig{
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

function Get-ContosoFlowRepoStatus {
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$Repos,

        $credential,
        $username,
        $password
    )
    Begin{
        if(-not($credential)){
            if($username -and $password){
                $credential = Set-TCCredential -username $username -password $password
            } else {
                throw "Credential object or Username and Password must be supplied"
            } 
        } 
    }
    Process {
        foreach ($Repo in $Repos)
        {
            $uri = "http://api.Contosoflow.foobar.com/repositories/search?enabledOnly=false&filter=$Repo"
            $ContosoFlowResponse = Invoke-RestMethod $uri -Method GET -UseDefaultCredentials
            if($ContosoFlowResponse.Count -gt 1){
                $ContosoFlowResponse = $ContosoFlowResponse | where{$_.name -eq $repo}
            }
            foreach ($response in $ContosoFlowResponse){
                    Test-ContosoFlowRepoConfig -ContosoFlowObj $response -credential $credential    
            }
        }
    }
}

Function Get-ID {
    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $name,
        [switch]$Octopus,
        [switch]$TeamCity
    )
    Begin {
        if ($Octopus -and $TeamCity)
        {
            throw "Unable to use both Octopus and TeamCity switches at the same time. Please specifiy only one"
        }
    }
    Process {
        foreach ($item in $name)
        {
            switch ($item)
            {
                'Lotteries.TaGs.Host' { if($TeamCity){'ContinuousDelivery_LotteriesCore_TaGsHost_1BuildTestPackagePublishCreateRelease'}elseif($Octopus){'tags-host'}}
                'Lotteries.TaGs.DB' { if($TeamCity){'ContinuousDelivery_LotteriesCore_TaGs_Database_1BuildPackagePublish'}elseif($Octopus){'tags-database'}}
                'Lotteries.TaGs.Reports'{ if($TeamCity){ 'ContinuousDelivery_LotteriesCore_TaGs_Reports_1BuildPackagePublish'}elseif($Octopus){'tags-reports'}}
                'Lotteries.Financial.DB' { if($TeamCity){ 'ContinuousDelivery_LotteriesCore_Financial_Database_LotteriesFinancialDb'}elseif($Octopus){'tags-financials-database'}}
                'Lotteries.Tocis.WebServices' { if($TeamCity){ 'TaGs_Tocis_TocisWebServices_1BuildTestPackagePublishCreateRelease'}elseif($Octopus){'tocis-webservices'}}
                'Lotteries.Tocis.Client' { if($TeamCity){ 'TaGs_Tocis_TocisClient_1BuildTestPackagePublishCreateRelease'}elseif($Octopus){'tocis-client'}}
                'Lotteries.ASL' { if($TeamCity){ 'ContinuousDelivery_LotteriesCore_Mosaic_AslModulesLotteries_BuildAslModulesLotte'}elseif($Octopus){'asl-modules-lotteries'}}
                Default {Write-Error "`nThe repo/project name:$item is not a valid option`n" -ErrorAction Continue}
            }
        }
    }
}

function Get-TCBuildConfig {
    Param(
        [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        $credential,

        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $TCBuildID
    )
    Begin{
        if(-not($credential)){
            if($username -and $password){
                $credential = Set-TCCredential -username $username -password $password
            } else {
                throw "Credential object or Username and Password must be supplied"
            } 
        } 
    }
    Process {
        foreach ($ID in $TCBuildID)
        {
            Invoke-RestMethod "http://teamcity.foobar.com/httpAuth/app/rest/buildTypes/id:$ID" -Credential $credential    
        }
    }
}

function Get-TCBuildFeatures {
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $TCBuildConfig
    )
    Process {
        foreach ($Build in $TCBuildConfig)
        {
            $ProjectID  = $Build.buildtype.projectId
            $Features = $Build.buildtype.features.feature
            
            [pscustomobject]@{
                ProjectID = $ProjectID
                Features = $Features
            }    
        }
    }
}

Function Set-TCCredential {
    param(
        [string]$username,
        [string]$password
    )
    $passwordSS = $password | ConvertTo-SecureString -asPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username,$passwordSS)
    Write-Output $credential
}
