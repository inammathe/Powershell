<#
.SYNOPSIS
    Fully extends a drive of one or more remote servers
.DESCRIPTION
    Asynchronously attempts  to extend a specified drive to the maximum available space on one or more remote servers using cmdlets available to Windows Server 2012 R2 and Windows 8.1 and above
    Useful for managing multiple virtual drives on remote servers after provisioning extra space.
.PARAMETER ComputerName
    One or more remote computer names to attempt to connect to via WinRM and extend drive space on
.PARAMETER DriveLetter
    The drive to be extended
.EXAMPLE
    PS C:\> Extend-RemoteDrives.ps1 -Servers ('server1','server2') -DriveLetter 'D' -Credential (Get-Credential)
    Attempts to Extend D drive on server1 and server2

    outputs:

    ComputerName Drive SizeBefore SizeAfter
    ------------ ----- ---------- ---------
    server1      D            100       120
    server2      D            50        120
.NOTES
    This script relies on functioning WinRM comms between the host and remote servers
    Requries remote servers to be Windows Server 2012 R2 and Windows 8.1 or above

    NAME        :  Resize-RemoteDrives.ps1
    VERSION     :  1.00
    LAST UPDATED:  14/07/2017
    AUTHOR      :  Evan Lock
#>
Function Resize-RemoteDrives
{
    [CmdletBinding(
        SupportsShouldProcess=$true,
        ConfirmImpact='Medium')]
    Param(
        [Parameter(
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            ValueFromRemainingArguments=$false)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DriveLetter,

        [Parameter(Mandatory=$true)]
        [PSCredential]
        $Credential
    )
    Begin
    {
        Write-Verbose "`Start - Executing Function: $($PSCmdlet.MyInvocation.MyCommand.Name),`nHost: $($env:COMPUTERNAME),`nTime: $(Get-Date)`n"

        $scriptBlock = {
            param($DriveLetter)

            # Get the specified drive partition information
            $Drive = (Get-Partition | Where-Object {$_.DriveLetter -eq $DriveLetter})
            $sizeBefore = [MATH]::Round($Drive.Size/1GB)

            # Get the maximum provisioned drive space for this partition and extend if space is available
            $Size = Get-PartitionSupportedSize -DiskNumber $Drive.DiskNumber -PartitionNumber $Drive.PartitionNumber
            $sizeMax = [Math]::Truncate(($Size.Sizemax - $Drive.Offset) / 1GB)
            if($sizeMax -lt $Drive.Size)
            {
                # Attempt to resize the partition
                Resize-Partition -DiskNumber $Drive.DiskNumber -PartitionNumber $Drive.PartitionNumber -Size $Size.SizeMax

                # Get the drive's new partition size
                $Drive = (Get-Partition | Where-Object {$_.DriveLetter -eq $DriveLetter})
                $sizeAfter = [MATH]::Round($Drive.Size/1GB)

                [pscustomobject]@{
                    ComputerName = $env:COMPUTERNAME
                    Drive = $DriveLetter
                    SizeBefore = $sizeBefore
                    SizeAfter = $sizeAfter
                }
            }
            else
            {
                # Report failure if drive cannot be extended
                Write-Error "MaxSize: $sizeMax `nCannot extend $DriveLetter Drive on $($env:COMPUTERNAME)"
            }
        }
    }
    Process
    {
        # Execute the ScriptBlock against each remote computer
        foreach ($computer in $ComputerName) {
            if ($pscmdlet.ShouldProcess($computer, "Command is invoked as $($Credential.UserName) and attempts to extend $DriveLetter drive"))
            {
                Invoke-Command -Credential $Credential -ComputerName $computer -ScriptBlock $scriptBlock -ArgumentList $DriveLetter -JobName "$($PSCmdlet.MyInvocation.MyCommand.Name)-$computer" -AsJob
                $resultsPresent = $true
            }
        }
    }
    End
    {
        #Get the results
        if($resultsPresent)
        {
            $results = Get-Job -Name "$($PSCmdlet.MyInvocation.MyCommand.Name)*"| Wait-Job -Timeout 20
            foreach ($result in $results)
            {
                Write-Verbose "Receiving job from: $($result.Location) with state: $($result.State)"
                Receive-Job -Job $result
            }

            #Remove jobs
            $results | Remove-Job
        }

        Write-Verbose "End - executed Function: $($PSCmdlet.MyInvocation.MyCommand.Name)"
    }
}