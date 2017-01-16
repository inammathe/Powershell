function Get-ContosoFlowRepoStatus {
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]$Repos,
        $credential,
        $username,
        $password
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
        foreach ($Repo in $Repos)
        {
            $uri = "http://api.Contosoflow.foobar.com/repositories/search?enabledOnly=false&filter=$Repo"
            $ContosoFlowResponse = Invoke-RestMethod $uri -Method GET -UseDefaultCredentials
            if($ContosoFlowResponse.Count -gt 1){
                $ContosoFlowResponse = $ContosoFlowResponse | where{$_.name -eq $repo}
            }
            foreach ($response in $ContosoFlowResponse){
                    Test-ContosoFlowRepoConfig -ContosoFlowObj $response -credential $credential    
            }
        }
    }
}
