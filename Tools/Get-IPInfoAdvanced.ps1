function Get-IPInfoAdvanced {
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [String]
        $loginAlias,
        [Parameter(Mandatory=$false,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$true,
            Position=1)]
        [String]
        $lokiID,
        [Parameter(Mandatory=$false,
            Position=2)]
        [Switch]
        $exportExcel,
        [Parameter(Mandatory=$true)]
        [datetime]
        $StartRange,
        [Parameter(Mandatory=$false)]
        [datetime]
        $EndRange
    )
    $StartDate = $StartRange.ToString('yyyy-MM-dd')
    if ($EndRange)
    {
        $EndDate = $EndRange.ToString('yyyy-MM-dd')    
    }
    else
    {
        $EndDate = (get-date).ToString('yyyy-MM-dd')
    }
    
    . \\contosoramle13ap\secure\DIV\TECHNOLOGY\APS\Digital\PSScripts\Tools\Invoke-Sqlcmd2.ps1
    if ($lokiID)
    {
        $sqlScript = "select * from AslLogIP.dbo.Logins
        where (Username = '$loginAlias' or Username = '$lokiID')
        and TimeStamp between '$StartDate 00:00:00' and '$EndDate 00:00:00'
        order by TimeStamp Desc"    
    }
    else
    {
        $sqlScript = "select * from AslLogIP.dbo.Logins
        where (Username = '$loginAlias')
        and TimeStamp between '$StartDate 00:00:00' and '$EndDate 00:00:00'
        order by TimeStamp Desc"     
    }
    
    $URL = "http://www.lookup-ip-address.info/ip-address/"
    $results = Invoke-Sqlcmd2 -ServerInstance contosofooDBS01DB -Query $sqlScript -as PSObject
    $resultTable = @()
    foreach ($item in $results)
    {
       $row = New-Object PSCustomObject -Property @{
            "TimeStamp" = $item.TimeStamp
            "IPAddress" = $item.IPAddress  
            "URLText" = $URL + ([string]$item.IPAddress)   
        }    
        $resultTable += $row
    }
    $resultTable# | Sort-Object -Unique IPAddress #|ft -AutoSize
    #$results | Select-Object -Property Timestamp, Username, IPAddress |ft -AutoSize
    Import-Module "\\contosoramle13ap\secure\DIV\TECHNOLOGY\APS\Digital\PSScripts\Modules\ImportExcel\ImportExcel.psm1"
    if($exportExcel){
        $resultTable | Select-Object -Property Timestamp, IPAddress <#, URL #> | Sort-Object -Property TimeStamp -Descending  | Export-Excel -WorkSheetname "IP Details" -AutoSize -Path "C:\temp\$($loginAlias.Split("@")[0])_IPdetails.xlsx"
    }
    #$sqlScript
}
