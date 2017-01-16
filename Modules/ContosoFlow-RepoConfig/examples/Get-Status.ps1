#requires -module ContosoFlow-RepoConfig
Get-ContosoFlowRepoStatus -credential (Get-Credential) -Repos (Get-Content "$PSScriptRoot\ContosoFlowConfig_RepoNames.txt") | Sort-Object -Property healthy -Descending
