. $PSScriptRoot/Utils.ps1

Get-ChildItem -Path $PSScriptRoot/Completions -Filter "*.ps1" | ForEach-Object {
    if (Get-Command -Name $_.BaseName -ErrorAction SilentlyContinue) {
        . $_.FullName
    }
}