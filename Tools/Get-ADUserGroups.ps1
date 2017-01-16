function Get-ADUserGroups {
<#
.SYNOPSIS
Returns groups that a AD user object are a member of.
.DESCRIPTION
Returns groups that a AD user object are a member of.
.PARAMETER User
Array of usernames to be used
.EXAMPLE
PS C:\> Get-ADUserGroups -User 'evan.lock'
Gets all groups that 'evan.lock' is a member of
.EXAMPLE
PS C:\> 'evan.lock','john.smith' | Get-ADUserGroups
retrieves all groups that evan.lock and john smith are members of
.NOTES
NAME        :  Get-ADUserGroups
VERSION     :  1.0   
LAST UPDATED:  16/01/2017
AUTHOR      :  TATTSGROUP\evan.lock
.INPUTS
string array of usernames
.OUTPUTS
PSCustomObject comining username and group membership
#>
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeLine=$true)]
        [Alias("ID","Users")]
        [string[]]$User
    )
    Begin {
       Try { Import-Module ActiveDirectory -ErrorAction Stop }
       Catch { Write-Host "Unable to load Active Directory module, is RSAT installed?"; Break }
    }
 
    Process {
        ForEach ($U in $User)
        {  
            $UN = Get-ADUser $U -Properties MemberOf
            $Groups = ForEach ($Group in ($UN.MemberOf))
            {   
                (Get-ADGroup $Group).Name
            }
            $Groups = $Groups | Sort
            ForEach ($Group in $Groups)
            {  
                [pscustomobject]@{
                    Name = $UN.Name
                    Group = $Group
                }
            }
        }
    }
}
