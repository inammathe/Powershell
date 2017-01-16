Function Initialize-iControl 
{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$LoadBalancerPrimary,
        
        [Parameter(Mandatory=$false)]
        [string]$Partition,
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [string]$Password
    )
    Initialize-F5.iControl -HostName $LoadBalancerPrimary -Username $Username -Password $Password -ErrorAction Stop  | Out-Null 
    $LBiControl = Get-F5.iControl -ErrorAction stop
    if($Partition){
        $LBiControl.ManagementPartition.set_active_partition($Partition)
    }
    Write-Output $LBiControl
}
Function Get-F5PoolMemberState 
{
<#
.Synopsis
   Retrieves F5 pool member information for later use
.DESCRIPTION
   Utilizes iControlSnapIn methods to query an array of F5 pools on a specified load balancer with the intention of retrieving all useful pool member information.
.PARAMETER PoolNames
   The F5 pool name/s required for this function. May be piped in or specified explicitly as a parameter
.PARAMETER LoadBalancerPrimary
   The name of the loadbalancer that contains the required pool members
.PARAMETER Partition
   If the load balancer is partitioned, you may specify the desired partition name here
.PARAMETER Username
   Username required to authenticate a user against the load balancer so that the i5 control may be initilazed and used.
.PARAMETER Password
   Password required to authenticate a user against the load balancer so that the i5 control may be initilazed and used.
.EXAMPLE
   Get-F5PoolMemberState -PoolNames ('PL_Inplay.api.Contoso.com_HTTPS','PL_Contoso.com_TIER1_New', 'PL_Contoso.com_TIER2_New') -LoadBalancerPrimary 'contoso-fooEXT05.foobar.com' -Partition 'Contoso_Portal'
.EXAMPLE
   ('PL_Inplay.api.Contoso.com_HTTPS','PL_Contoso.com_TIER1_New', 'PL_Contoso.com_TIER2_New') | Get-F5PoolMemberState -LoadBalancerPrimary 'contoso-fooEXT05.foobar.com'
.INPUTS
   String array of pool names
.OUTPUTS
   PScustomObject array of pool member information
    -Pool
    -Address
    -Port
    -Availability
    -Enabled
    -Description    
.NOTES
   Author:Evan Lock
   Email:evan.lock@foobar.com
   Date:10/05/2016
.COMPONENT
   The primary components of this cmdlet belongs to the f5 icontrol library
.FUNCTIONALITY
   Retrieves F5 pool member information for later use
.LINK
   https://devcentral.f5.com/wiki/iControl.PowerShell.ashx
#>
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullorEmpty()]
        [string[]]$PoolNames = 'PL_Contoso.com_TIER1_New',
        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]$LoadBalancerPrimary = 'contoso-fooEXT05.foobar.com',
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$LoadBalancerSecondary = 'contoso-fooEXT05.foobar.com',
        
        [Parameter(Mandatory=$false)]
        [string]$Partition = 'Contoso_Portal',
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]$Password
    )
    Begin 
    {
        Write-Verbose -Message "$($MyInvocation.MyCommand.Name):: Function started"
        if ( (Get-PSSnapin | Where-Object { $_.Name -eq "iControlSnapIn"}) -eq $null )
        {
            Try {
                Add-PSSnapIn iControlSnapIn -ErrorAction Stop
            } Catch {
                Write-Error "Failed to add iControlSnapIn : $($Error[0])" -ErrorAction Stop
            }
        }
        Try {
            $LBiControl = Initialize-iControl -LoadBalancerPrimary $LoadBalancerPrimary -Partition $Partition -Username $Username -Password $Password -ErrorAction Stop
        } Catch {
            if($LoadBalancerSecondary){
                Try {
                    Write-Warning "Failed to initialize the iControl using the loadbalancer $LoadBalancerPrimary, attempting $LoadBalancerSecondary"
                    $LBiControl = Initialize-iControl -LoadBalancerPrimary $LoadBalancerSecondary -Partition $Partition -Username $Username -Password $Password -ErrorAction Stop
                } Catch {
                        write-error "Failed to initialize the iControl : $($Error[0])" -ErrorAction stop
                }
            } else {
                write-error "Failed to initialize the iControl : $($Error[0])" -ErrorAction stop
            }
        }
    }
    Process 
    {
        foreach($Pool in $PoolNames) {
            $MemberObjectStatusObject = $LBiControl.LocalLBPoolMember.get_object_status((, $Pool))
            if(!($MemberObjectStatusObject)){
                [pscustomobject]@{
                    Pool = $Pool
                    Address = 'N/A'
                    Port = 'N/A'
                    Availability = 'N/A'
                    Enabled = 'N/A'
                    Description = "PoolName:$Pool does not exist on $LoadBalancerPrimary"
                }
            } else {
                $MemberObjectStatus = $MemberObjectStatusObject[0] #because there is only one pool
                foreach ($F5obj in $MemberObjectStatus) {
                    [pscustomobject]@{
                        Pool = $Pool
                        Address = $F5obj.member.address
                        Port = $F5obj.member.port
                        Availability = $F5obj.object_status.availability_status
                        Enabled = $F5obj.object_status.enabled_status
                        Description = $F5obj.object_status.status_description
                    }
                }
            }  
        }
    }
    End
    {
        Write-Verbose -Message "$($MyInvocation.MyCommand.Name):: Function ended"
    }   
}
Function Get-HostIPaddress 
{
    $hostname = & hostname.exe
    
    $IP =(test-connection $hostname -timetolive 2 -count 1).IPV4Address.IPAddressToString
    
    $N1 = ([system.net.dns]::gethostbyName(“$hostname”)).hostname
    $N2 = ([system.net.dns]::gethostbyaddress($IP)).hostname 
    IF($N1 -eq $N2) {
        $Conflict = $False        
    } else {
        $Conflict = $True
    }
    if($Conflict) {
        [pscustomobject]@{
            IPAddress =  $IP
            DNSConflict = $Conflict
            Hostnames = @($N1,$N2)
        }
    } else {
        [pscustomobject]@{
            IPAddress =  $IP
            DNSConflict = $Conflict
        }
    }
}

param(
    [Parameter(Mandatory)]
    [ValidateSet('Enabled','Disabled','Offline')]
    [string]$State,
    [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,
    HelpMessage = 'PL_Contoso.com_TIER1_New')]
    [ValidateNotNullorEmpty()]
    [string[]]$PoolNames,
        
    [Parameter(Mandatory=$true,
    HelpMessage = 'contoso-fooEXT05.foobar.com')]
    [ValidateNotNullorEmpty()]
    [string]$LoadBalancerPrimary,
    [Parameter(Mandatory=$false,
    HelpMessage = 'contoso-fooEXT05.foobar.com')]
    [ValidateNotNullorEmpty()]
    [string]$LoadBalancerSecondary,
        
    [Parameter(Mandatory=$false,
    HelpMessage = 'Contoso_Portal')]
    [string]$Partition,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [string]$Username,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullorEmpty()]
    [string]$Password
)
<# octo param use example
    $PoolNames = $OctopusParameters['PoolNames']
    $LBPrimary = $OctopusParameters['LBPrimary']
    $LBSecondary = $OctopusParameters['LBSecondary']
    $Username = $OctopusParameters['Username']
    $Password = $OctopusParameters['Password']
    $Partition = $OctopusParameters['Partition']
#>
$F5StateObject = Get-F5PoolMemberState -LoadBalancerPrimary $LBPrimary -LoadBalancerSecondary $LBSecondary -PoolNames $PoolNames  -username $Username -password $Password -Partition $Partition
foreach($item in $F5StateObject) {
    $MemberString = "$($item.Address):$($item.Port)"
    
    Write-Verbose "Disabling F5 member:$MemberString in Pool:$($item.Pool)"
    
    Try {
        Set-F5.LTMPoolMemberState -Pool $item.Pool -Member $MemberString -State $DesiredState -ErrorAction Stop
    } Catch {
        Write-Error "Failed to disable member $MemberString - $($Error[0])" -ErrorAction Continue
    }
}
