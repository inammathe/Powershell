#requires -module ContosoFlow-RepoConfig
$UnhealthyRepos = (Get-ContosoFlowRepoStatus -Repos (Get-Content "$PSScriptRoot\ContosoFlowConfig_RepoNames.txt") | Where-Object {-not($_.healthy)}).name
$UnhealthyRepos | Restore-ContosoFlowConfig -JSONTemplate "$PSScriptRoot\ContosoFlowConfig_Template.JSON"
