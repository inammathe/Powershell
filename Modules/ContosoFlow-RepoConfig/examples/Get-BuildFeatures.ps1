#requires -module ContosoFlow-RepoConfig
Get-Content "$PSScriptRoot\ContosoFlowConfig_RepoNames.txt" |
Get-ID -TeamCity | 
Get-TCBuildConfig -credential (Get-Credential) |
Get-TCBuildFeatures
