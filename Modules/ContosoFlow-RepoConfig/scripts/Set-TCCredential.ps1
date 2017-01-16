Function Set-TCCredential {
    param(
        [string]$username,
        [string]$password
    )
    $passwordSS = $password | ConvertTo-SecureString -asPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($username,$passwordSS)
    Write-Output $credential
}
