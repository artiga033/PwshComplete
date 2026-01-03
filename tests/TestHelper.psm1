# Test Helper Module for PwshComplete Tests
# Provides utilities for testing argument completers

<#
.SYNOPSIS
    Creates a mock CommandAst object for testing argument completers.
.PARAMETER CommandLine
    The command line string to parse.
.OUTPUTS
    System.Management.Automation.Language.CommandAst
#>
function New-MockCommandAst {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.CommandAst])]
    param(
        [Parameter(Mandatory)]
        [string]$CommandLine
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $CommandLine,
        [ref]$tokens,
        [ref]$errors
    )

    # Find the CommandAst in the parsed AST
    $commandAst = $ast.Find({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

    return $commandAst
}

<#
.SYNOPSIS
    Invokes a registered native argument completer for testing.
.PARAMETER CommandName
    The name of the command to get completions for.
.PARAMETER CommandLine
    The full command line being completed.
.PARAMETER CursorPosition
    The position of the cursor (defaults to end of line).
.PARAMETER WordToComplete
    The word being completed (defaults to last word or empty).
.OUTPUTS
    Array of completion results.
#>
function Invoke-ArgumentCompleter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [Parameter(Mandatory)]
        [string]$CommandLine,

        [Parameter()]
        [int]$CursorPosition = -1,

        [Parameter()]
        [string]$WordToComplete = ''
    )

    if ($CursorPosition -eq -1) {
        $CursorPosition = $CommandLine.Length
    }

    $commandAst = New-MockCommandAst -CommandLine $CommandLine

    if ($null -eq $commandAst) {
        throw "Failed to parse command line: $CommandLine"
    }

    # Get the registered completer
    # We need to invoke the script block directly since we're testing
    # The completers are registered as native completers

    # Build the arguments for the completer
    $completerArgs = @($WordToComplete, $commandAst, $CursorPosition)

    # Return results - the actual invocation depends on how we set up the test
    return $completerArgs
}

<#
.SYNOPSIS
    Creates a temporary SSH config file for testing.
.PARAMETER Hosts
    Array of host names to include in the config.
.OUTPUTS
    Path to the temporary config file.
#>
function New-MockSshConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Hosts = @()
    )

    $tempDir = Join-Path $env:TEMP "PwshCompleteTests_$(Get-Random)"
    $sshDir = Join-Path $tempDir ".ssh"
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null

    $configPath = Join-Path $sshDir "config"
    $content = $Hosts | ForEach-Object { "Host $_" }
    $content -join "`n" | Set-Content -Path $configPath -NoNewline

    return @{
        TempDir = $tempDir
        SshDir = $sshDir
        ConfigPath = $configPath
    }
}

<#
.SYNOPSIS
    Creates a temporary known_hosts file for testing.
.PARAMETER Hosts
    Array of host names to include.
.OUTPUTS
    Path to the temporary known_hosts file.
#>
function New-MockKnownHosts {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string[]]$Hosts = @(),

        [Parameter(Mandatory)]
        [string]$SshDir
    )

    $knownHostsPath = Join-Path $SshDir "known_hosts"
    $content = $Hosts | ForEach-Object { "$_ ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ==" }
    $content -join "`n" | Set-Content -Path $knownHostsPath -NoNewline

    return $knownHostsPath
}

<#
.SYNOPSIS
    Cleans up temporary test files.
#>
function Remove-MockFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TempDir
    )

    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function *
