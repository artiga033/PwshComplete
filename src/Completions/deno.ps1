if (Get-Command -Name "deno" -ErrorAction SilentlyContinue) {
    deno completions powershell | Out-String | Invoke-Expression
}