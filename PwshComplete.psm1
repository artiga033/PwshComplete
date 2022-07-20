function Add-Completions {
    Get-ChildItem -Path ./Completions -Filter "*.ps1" | ForEach-Object {
        . $_
    }
}