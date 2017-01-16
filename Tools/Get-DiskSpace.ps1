function Get-DiskSpace {
<#
.SYNOPSIS
Returns the percentage of disk space free
.DESCRIPTION
Uses Get-wmiobject to return the percentage of diskspace free on every drive with a configurable treshold warning. Can be used against multiple machines.
.PARAMETER ComputerName
Name or Names of computers to be queried for disk space. Default is the computer the script is run from.
.PARAMETER Threshold
Integer threshold for the warning. Default is 20.
.EXAMPLE
'Computer1','Computer2' | Get-DiskSpace -Threshold 10
Gets diskspace from both computers with a warning threshold of 10 percent
example output:
Computer      Drive PercentFree BelowThreshold Errors                            
--------      ----- ----------- -------------- ------                            
COMPUTER1      C:            18          False                                   
COMPUTER1      E:            78          False                                   
COMPUTER2                                       System.UnauthorizedAccessException
.NOTES
NAME        :  Get-DiskSpace
VERSION     :  1.00   
LAST UPDATED:  30/12/2016
AUTHOR      :  Evan Lock
.INPUTS
String array of computer names
.OUTPUTS
PSCustomObject
#>
    param(
        [string[]][Parameter(Mandatory=$false,ValueFromPipeline)]$ComputerName,
        [int][Parameter(Mandatory=$false)]$Threshold = 20
    )
    Begin
    {
        Write-Verbose "$(Get-Date) - Get-Diskpace run from $($env:COMPUTERNAME) by $($env:USERNAME)"
        if (!$ComputerName)
        {
            $ComputerName = $env:COMPUTERNAME
        }
    }
    Process
    {
        foreach ($Computer in $ComputerName)
        {   
            $colDisks = @()
            Try
            {
                $colDisks = get-wmiobject Win32_LogicalDisk -ComputerName $Computer -Filter "DriveType = 3" -ErrorAction Stop
                foreach ($disk in $colDisks) {
                    $BelowThreshold = $false
                    if ($disk.size -gt 0) {
                        $PercentFree = [Math]::round((($disk.freespace/$disk.size) * 100))
                    }
                    else 
                    {
                        $PercentFree = 0
                    }
                    if ($PercentFree -le $Threshold)
                    {
                        $BelowThreshold = $true
                    }
                    [pscustomobject]@{
                        Computer = $Computer.ToUpper()
                        Drive = $disk.DeviceID
                        PercentFree = $PercentFree
                        BelowThreshold = $BelowThreshold
                        Errors = $null
                    } 
                } 
            }
            Catch
            {
                [pscustomobject]@{
                    Computer = $Computer.ToUpper()
                    Drive = $null
                    PercentFree = $null
                    BelowThreshold = $null
                    Errors = $Error[0].Exception.GetType().FullName
                }
                
            }
        }
    }
        
    End
    {
       Write-Verbose "$(Get-Date) - Get-Diskpace finished"
    }
}
