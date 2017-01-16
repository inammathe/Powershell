#requires -Modules octoPosh
function Get-OctoReleaseLinks {
<#
.SYNOPSIS
Gets the very latest Octopus release links for any number of specified projects
.DESCRIPTION
Uses the Octopus API (through use of an external module 'OctoPosh') to get the latest created releases based on creation time. 
The default branch chosen is master however you may specify a branch
.PARAMETER ProjectName
Name of the octopus project. e.g. ASL.Modules.Loki'
.PARAMETER Branch
Optional branch parameter e.g. US26913
.PARAMETER CopyToClipboard
Optional switch that copies the output to the clipboard
.EXAMPLE
PS C:\> 'ASL.Modules.Loki','Mosaic.Modules.Loki' | Get-OctoReleaseLinks -CopyToClipboard
Gets the latest master release links created for those two projects and copies the output to the clipboard
.NOTES
NAME        :  Get-OctoReleaseLinks
VERSION     :  1.00   
LAST UPDATED:  16/11/2016
AUTHOR      :  foobar\evan.lock
.LINK
https://github.foobar.com/evan-lock/PowerShell/blob/master/Tools/Octopus/Get-OctoReleaseLinks.ps1
.LINK
https://github.com/Dalmirog/OctoPosh 
.INPUTS
string array of project names
.OUTPUTS
string array of octopus release links
#>
    [CmdletBinding()]
    Param(
        [parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            HelpMessage = 'Name of the octopus project. e.g. ASL.Modules.Loki')]
        [ValidateNotNullorEmpty()]
        [string[]]
        $ProjectName,
        [parameter(
            Mandatory=$false,
            HelpMessage = 'Name of the branch. e.g. US26913')]
        [ValidateNotNullorEmpty()]
        [string]
        $Branch = 'master',
        [parameter(
            Mandatory=$false,
            HelpMessage = 'Copies output to clipboard')]
        [ValidateNotNullorEmpty()]
        [switch]
        $CopyToClipboard,
        [parameter(
            Mandatory=$false,
            HelpMessage = 'formats')]
        [ValidateNotNullorEmpty()]
        [switch]
        $Format,
        [parameter(
            Mandatory=$false,
            HelpMessage = 'formats')]
        [ValidateNotNullorEmpty()]
        [switch]
        $Latest
    )
    Begin
    {
        $links = @()
    }
    Process
    {
        foreach ($project in $ProjectName)
        {
            if(!$latest){
                $r = Get-OctopusRelease -ProjectName $project | where {$_.ReleaseNotes -like "*$Branch*"} | Sort-Object -Property CreationDate -Descending | Select-Object -First 1
            } else {
                $r = Get-OctopusRelease -ProjectName $project -Latest 1
            }
            if ($Format)
            {
                $links += "`n$Project - $($r.ReleaseVersion)" 
                $links += Join-Parts -Parts ($env:OctopusURL, $r.Resource.links.web) -Separator '/' 
            }
            else
            {
                $links += Join-Parts -Parts ($env:OctopusURL, $r.Resource.links.web) -Separator '/' 
            }
        }
    }
    End
    {
        Write-Output $links
        if ($CopyToClipboard)
        {
            $links | clip   
        }
    }
}
