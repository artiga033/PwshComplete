. $PSScriptRoot/Utils.ps1

Get-ChildItem -Path $PSScriptRoot/Completions -Filter "*.ps1" | ForEach-Object {
    # Use -CommandType Application to skip aliases, functions, and cmdlets lookup (faster)
    # Use -ErrorAction Ignore instead of SilentlyContinue (doesn't populate $Error)
    if (Get-Command -Name $_.BaseName -CommandType Application -ErrorAction Ignore) {
        . $_.FullName
    }
}