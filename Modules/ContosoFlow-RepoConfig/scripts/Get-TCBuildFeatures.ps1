function Get-TCBuildFeatures {
    Param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        $TCBuildConfig
    )
    Process {
        foreach ($Build in $TCBuildConfig)
        {
            $ProjectID  = $Build.buildtype.projectId
            $Features = $Build.buildtype.features.feature
            
            [pscustomobject]@{
                ProjectID = $ProjectID
                Features = $Features
            }    
        }
    }
}
