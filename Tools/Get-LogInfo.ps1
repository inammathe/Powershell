function Get-LogInfo {
<#
.Synopsis
    Returns log information for logs generated on the same day as the log file passed to the function
        'LogName'
        'LogDate'
        'AvgSize(MB)'
        'SumSize(MB)'
        'AvgLines'
        'SumLines'
.DESCRIPTION
    Returns log information for logs of the same base name on the same day as the log path passed to the function
.PARAMETER LogPath
    Required. Specifies the logfile to be used to measure attributes based off of the file's base name and last modified properties
.EXAMPLE
    Get-LogInfo -LogPath \\contosowweb02.dmz.foobar\D$\NextGen.Logs\Service\ContosoPlugin.log.11
    Gets log file information relating to the logfile referenced via the -LogPath parameter
.EXAMPLE
    (Get-Content "C:\Temp\LogPathList.txt") | % {Get-LogInfo -LogPath $_} | Out-File C:\Temp\output.txt -Force
    Loops through a list list of paths in a file and outputs the result to another
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, HelpMessage='Enter the full path to the log file - Without quotes!')]
        [ValidateScript({Test-Path $_ -pathtype 'leaf'})]
        [string]$LogPath
    )
    #Get some information from the log file 
    $LogFile = Get-Item $LogPath
    $LogName = $LogFile.BaseName
    $date = (Get-Date $LogFile.LastWriteTime).Date
    
    #Get child items from the directory of the log file with the same base name and last modified date
    $logs = Get-ChildItem ($LogFile.Directory.FullName) -Force | 
        Where-Object {$_.LastWriteTime -ge $date -and $_.LastWriteTime -lt $date.AddDays(1) -and $_.BaseName -eq $LogName}
    #Get the sum of all lines in each of the found logs - uses IO.StreamReader to avoid memory issues
    $lineCount = 0
    foreach  ($log in $logs){
        $reader = New-Object IO.StreamReader $log.FullName
        while($reader.ReadLine() -ne $null){ $lineCount++ }
        $reader.Close()
    }
    #Get the average and sum size of the log files found
    $Measure = $logs | Measure-Object -Property Length -Average -sum
    #Round out some values
    $avgSize = [Math]::Round($Measure.Average/1mb, 2)
    $sumSize = [Math]::Round($Measure.Sum/1mb, 2)
    $avgLines = [Math]::Round($lineCount/$Measure.Count, 0)
    #create the output object and return it to the pipe
    return [pscustomobject][ordered]@{
        LogName = $LogName
        LogDate = $date.ToString('dd/MM/yyyy')
        'AvgSize(MB)' = $avgSize
        'SumSize(MB)' = $sumSize
        'AvgLines' = $avgLines
        'SumLines' = $lineCount
    }
}
