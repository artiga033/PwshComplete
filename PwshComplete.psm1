function Add-Completions {
    Get-ChildItem -Path $PSScriptRoot/Completions -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}