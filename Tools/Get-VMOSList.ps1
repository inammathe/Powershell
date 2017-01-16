#requires -Modules VMware.VimAutomation.Core
#"C:\Program Files (x86)\VMware\Infrastructure\PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
#download it from https://my.vmware.com/group/vmware/details?downloadGroup=PCLI650R1&productId=614
function Get-VMOSList {
    param(
        [Parameter(Mandatory=$false)][string]$Username,
        [Parameter(Mandatory=$false)][string]$Password,
        [Parameter(Mandatory=$false)][PSCredential]$Credential,
    
        #'Contososvsm01.Contosononprod.com'
        [Parameter(Mandatory=$false)]$VIServerName = 'Contososvsm01.Contosononprod.com',
        [Parameter(Mandatory=$false)]
        [string[]]$ComputerName
    )
    #setup Credentials
    if (!($Credential))
    {
        if (!($Username -or $Password))
        {
            throw "Credential object or username and password required"
        } else {
            $SecurePassword = $Password | ConvertTo-SecureString -asPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($Username,$SecurePassword)
        }
    }
    
    #connect to VIServer
    Connect-VIServer -Server $VIServerName -Credential $Credential -ErrorAction Stop
    #get vms
    if($ComputerName)
    {
        $vms = Get-VM -Name $ComputerName | where {$_.PowerState -ne 'PoweredOff'}
    } else {
        $vms = Get-VM | where {$_.PowerState -ne 'PoweredOff'}
    }
    #get OS and output object
    foreach ($vm in $vms)
    {
        [pscustomobject]@{
            Name = $vm.Name
            OS = $vm.guest.OSFullName
        } #| Export-Csv E:\Scripts\VMs\serverlist.csv -Append -NoTypeInformation
    }
}
