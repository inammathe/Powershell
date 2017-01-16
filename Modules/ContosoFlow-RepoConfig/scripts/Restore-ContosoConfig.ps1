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
function Restore-ContosoFlowConfig {
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
