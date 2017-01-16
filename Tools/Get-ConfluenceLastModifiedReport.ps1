<#
.SYNOPSIS
    Gets last modified date information from descendants of a page
.DESCRIPTION
    Allows the user to retrive and generate a report on the last modified dates from pages at any specified depth. uses the Atlassian REST API methods
.PARAMETER pageid
    Parent page id number
.PARAMETER limit
    Depth at which the child pages will be returned
.PARAMETER ExcludeLabel
    Label used to exclude pages from the report.
.PARAMETER username
    Your Confluence username
.PARAMETER password
    Your Confluence password
.PARAMETER credential
    Optional PSCredential input object that may be used in place of manually entered username and password
.PARAMETER Destination
    Optional path for report output. default is 'C:\temp\ConfluneceLastMod.html'
.EXAMPLE
    .\Get-ConfluenceLastModifiedReport.ps1; Get-ConfluenceLastModifiedReport -PageID 33587463 -Limit 15 -credential $credential
    .\Get-ConfluenceLastModifiedReport.ps1; Get-ConfluenceLastModifiedReport -PageID 33587463 -Limit 15 -username 'evan.lock' -password 'thisisnotmypassword'
.NOTES
NAME        :  Get-ConfluenceLastModifiedReport.ps1
VERSION     :  1.0   
LAST UPDATED:  20/05/2016
AUTHOR      :  foobar\Evan.Lock
https://developer.atlassian.com/confdev/confluence-rest-api
.LINK
.INPUTS
.OUTPUTS
#>
Function Get-ConfluenceLastModifiedReport {
    param(
        [Parameter(Mandatory)][string]$PageID,
        [Parameter(Mandatory=$false)][string]$Limit,
        [Parameter(Mandatory=$false)][string]$ExcludeLabel = 'report_exclude',
        [Parameter(Mandatory=$false)][string]$username,
        [Parameter(Mandatory=$false)][string]$password,
        [Parameter(Mandatory=$false)][string]$RptTitle = 'Confluence LastModified Report',
        [Parameter(Mandatory=$false)][PSCredential]$credential,
        [Parameter(Mandatory=$false)][string]$Destination = 'C:\temp\ConfluneceLastMod-RELEASE.html'
    )
   
    #Authentication
    if(!$credential){
        $credential = Set-Credential -username $username -password $password
    }
    
    #Get Child Page IDs
    $ChildPages = Get-DescendantIDs -ID $PageID -credential $credential -Limit $Limit
    $ChildPageIDs = $ChildPages.results.id
    
   
    #Get Info
    $Total = $ChildPageIDs.Count
    $Count = 0
    $results = @()
    foreach($id in $ChildPageIDs){
        Try {
            $pageLabels = Invoke-RestMethod -Uri "https://foobar.atlassian.net/wiki/rest/api/content/$id/label?os_authType=basic" -Credential $credential -Method get
            if($pageLabels.results.name -notcontains $ExcludeLabel){
                $results += Get-PageLastMod -ID $id -credential $credential
                $Count++
            }
        } Catch {
            Write-Error $Error[0] -ErrorAction Continue
        }
    }
    Write-Output "$Count of $Total checked successfully with $($Total - $Count) exclusions"
    
    #generate report
    Create-Report -results $results -Destination $Destination -RptTitle $RptTitle
}
Function Set-Credential {
    param(
        [string]$username,
        [string]$password
    )
    $passwordSS = $password | ConvertTo-SecureString -asPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username,$passwordSS)
    Write-Output $credential
}
Function Get-DescendantIDs {
    param(
        [string]$ID,
        [PSCredential]$credential,
        [string]$Limit
    )
    Invoke-RestMethod -Uri "https://foobar.atlassian.net/wiki/rest/api/content/$ID/descendant/page?os_authType=basic&limit=$Limit" -Credential $credential -Method get
}
Function Get-PageLastMod{
    param(
        [string]$ID,
        [PSCredential]$credential
    )
    $pageInfo = Invoke-RestMethod -Uri "https://foobar.atlassian.net/wiki/rest/api/content/$ID`?os_authType=basic" -Credential $credential -Method get
    [pscustomobject]@{
        Title = $pageinfo.title
        DaysSinceLastMod = [math]::Round(((get-date) - ([datetime]$pageinfo.version.when)).TotalDays, 0)
        LastModDate = [datetime]$pageinfo.version.when
        Link = "<a href=`"$($pageinfo._links.base)$($pageinfo._links.tinyui)`">$($pageinfo._links.base)$($pageinfo._links.tinyui)</a>"
    }
}
function Format-CSS {
    $CSS = "<style>"
    $CSS = $CSS + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse; margin: 5px;}"
    $CSS = $CSS + "TH{border-width: 1px;padding: 5px;border-style: solid;border-color: black; }"
    $CSS = $CSS + "TD{border-width: 1px;padding: 5px;border-style: solid;border-color: black; }"
    $CSS = $CSS + "</style>"
    $CSS
}
function Create-Report {
    param(
        $results,
        $Destination,
        $RptTitle
    )
    $CSS = Format-CSS
    $PreContent ="<h1>$RptTitle</h1>"
    $PostContent = "<br><strong>Report generated: $(get-date)</strong>"
    $HTML = $results | Sort-Object -Property DaysSinceLastMod -Descending | Select-Object -Property Title, DaysSinceLastMod, LastModDate, Link | ConvertTo-Html -PreContent $PreContent -Head $CSS -postcontent $PostContent
    #optional email sending
    #Send-Email -to 'DISTU_APSDIGITAL@foobar.com' -subject 'Uptime Report' -body $HTML
    #Send-Email -to 'evan.lock@foobar.com' -subject 'Uptime Report' -body $HTML
    Add-Type -AssemblyName System.Web
    [System.Web.HttpUtility]::HtmlDecode($HTML) | out-file $Destination -Force
    
}
function Send-Email {
    param(
        [Parameter(Mandatory=$true)][string[]]$to,
        [Parameter(Mandatory=$true)][string]$subject,
        [Parameter(Mandatory=$true)][Object]$body
    )
    $HTML = [string]$body
    $From = "aps-reports@foobar.com"
    $SMTPServer = "outboundsmtp.foobar.com"
    $SMTPPort = "25"
    Send-MailMessage -SmtpServer $SMTPServer -From $From -To $to -Body $HTML -BodyAsHtml -Subject $subject
    
}
