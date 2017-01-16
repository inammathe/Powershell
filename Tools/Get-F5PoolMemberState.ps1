Function Get-F5PoolMemberState {
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
   If the load balancer is partitioned, you may specify the desired partition name here (case sensitive)
.PARAMETER Username
   Username required to authenticate a user against the load balancer so that the i5 control may be initilazed and used.
.PARAMETER Password
   Password required to authenticate a user against the load balancer so that the i5 control may be initilazed and used.
.PARAMETER Credential
   Credential object that may be used in place of a plain text username and password
.EXAMPLE
   Get-F5PoolMemberState -PoolNames ('PL_Inplay.api.Contoso.com_HTTPS','PL_Contoso.com_TIER1_New', 'PL_Contoso.com_TIER2_New') -LoadBalancerPrimary 'contoso-fooEXT05.foobar.com' -Partition 'Contoso_Portal'
.EXAMPLE
   ('PL_Inplay.api.Contoso.com_HTTPS','PL_Contoso.com_TIER1_New', 'PL_Contoso.com_TIER2_New') | Get-F5PoolMemberState -LoadBalancerPrimary 'contoso-fooEXT05.foobar.com'
.INPUTS
   String array of pool names
.OUTPUTS
   PScustomObject array of pool member information
    -Pool
    -Hostname
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
        [string]$Partition,
        [Parameter(Mandatory=$false)]
        [string]$Username,
        [Parameter(Mandatory=$false)]
        [string]$Password,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )
    Begin 
    {
        Write-Verbose -Message "$($MyInvocation.MyCommand.Name):: Function started"
        
        Write-Verbose -Message "#Initialize the iControlSnapIn"
        if ( (Get-PSSnapin | Where-Object { $_.Name -eq "iControlSnapIn"}) -eq $null )
        {
            Try {
                Add-PSSnapIn iControlSnapIn -ErrorAction Stop
            } Catch {
                Write-Error "Failed to add iControlSnapIn : $($Error[0])" -ErrorAction Stop
            }
        }
        Write-Verbose -Message "#Set up credentials"
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
        Write-Verbose -Message "#Attempt to initialize the iControl"
        Try {
            $LB = $LoadBalancerPrimary
            $LBiControl = Initialize-iControl -LoadBalancer $LB -Partition $Partition -Credential $Credential -ErrorAction Stop
        } Catch {
            if($LoadBalancerSecondary){
                Try {
                    Write-Warning "Failed to initialize the iControl using the loadbalancer $LoadBalancerPrimary, attempting $LoadBalancerSecondary"
                    $LB = $LoadBalancerSecondary
                    $LBiControl = Initialize-iControl -LoadBalancer $LB -Partition $Partition -Credential $Credential -ErrorAction Stop
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
        Write-Verbose -Message "Iterate through the returned objects and create and return a useful object"
        foreach($Pool in $PoolNames) {
            $MemberObjectStatusObject = $LBiControl.LocalLBPoolMember.get_object_status((, $Pool))
            if(!($MemberObjectStatusObject)){
                throw "PoolName:$Pool does not exist on $LoadBalancerPrimary"
            } else {
                
                $MemberObjectStatus = $MemberObjectStatusObject[0] #because there is only one pool(get_object_status() is weird like that)
                foreach ($F5obj in $MemberObjectStatus) {
                    Try {
                        $HostName = ([System.Net.Dns]::gethostentry($F5obj.member.address)).hostname
                    } Catch {
                        $HostName = 'Unable to get hostname'
                    }
                    [pscustomobject]@{
                        Pool = $Pool
                        Host = $HostName
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
Function Initialize-iControl {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$LoadBalancer,
        
        [Parameter(Mandatory=$false)]
        [string]$Partition,
        [Parameter(Mandatory=$false)]
        [string]$Username,
        [Parameter(Mandatory=$false)]
        [string]$Password,
        [Parameter(Mandatory=$false)]
        [PSCredential]$Credential
    )
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
    Initialize-F5.iControl -HostName $LoadBalancerPrimary -Credentials $Credential -ErrorAction Stop  | Out-Null 
    $LBiControl = Get-F5.iControl -ErrorAction stop
    if($Partition){
        $LBiControl.ManagementPartition.set_active_partition($Partition)
    }
    Write-Output $LBiControl
}
