function Get-TCBuildConfig {
    Param(
        [parameter(Mandatory=$true)]
        $credential,
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $TCBuildID
    )
    Begin{
        if(-not($credential)){
            if($username -and $password){
                $credential = Set-TCCredential -username $username -password $password
            } else {
                throw "Credential object or Username and Password must be supplied"
            } 
        } 
    }
    Process {
        foreach ($ID in $TCBuildID)
        {
            Invoke-RestMethod "http://teamcity.foobar.com/httpAuth/app/rest/buildTypes/id:$ID" -Credential $credential    
        }
    }
}
