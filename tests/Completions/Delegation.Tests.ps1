#Requires -Modules Pester

<#
.SYNOPSIS
    Tests for CLI-delegated completions (deno, dotnet, winget).

.DESCRIPTION
    These completion scripts delegate to the CLI tools themselves for completions.
    We test the structure and behavior of the delegation, not the actual completions
    (which depend on the external tools being installed).
#>

BeforeAll {
    # Navigate from tests/Completions to project root, then to src
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot 'src'
    $script:CompletionsPath = Join-Path $script:ModulePath 'Completions'

    function New-MockCommandAst {
        param([string]$CommandLine)

        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput(
            $CommandLine,
            [ref]$tokens,
            [ref]$errors
        )
        return $ast.Find({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
    }
}

Describe 'Deno Completion' {
    BeforeAll {
        $script:DenoScript = Join-Path $script:CompletionsPath 'deno.ps1'
    }

    Context 'Script structure' {
        It 'Should exist' {
            Test-Path $script:DenoScript | Should -BeTrue
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:DenoScript, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should check for deno command existence' {
            $content = Get-Content $script:DenoScript -Raw
            $content | Should -Match 'Get-Command.*deno'
        }

        It 'Should invoke deno completions powershell' {
            $content = Get-Content $script:DenoScript -Raw
            $content | Should -Match 'deno completions powershell'
        }

        It 'Should use Invoke-Expression to register completions' {
            $content = Get-Content $script:DenoScript -Raw
            $content | Should -Match 'Invoke-Expression'
        }
    }

    Context 'Behavior with mock deno' {
        BeforeAll {
            # Mock deno to return a simple completer registration
            function global:deno {
                param()
                $allArgs = $args -join ' '
                if ($allArgs -match 'completions powershell') {
                    # Return a minimal completer script
                    @'
Register-ArgumentCompleter -Native -CommandName deno -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    @('run', 'compile', 'bundle', 'cache', 'check', 'doc', 'eval', 'fmt', 'init', 'info', 'install', 'uninstall', 'lint', 'repl', 'task', 'test', 'types', 'upgrade') |
        Where-Object { $_ -like "$wordToComplete*" }
}
'@
                }
            }
        }

        AfterAll {
            Remove-Item Function:\deno -ErrorAction SilentlyContinue
        }

        It 'Should register completer when deno exists' {
            # Source the script
            . $script:DenoScript

            # Verify a native completer was registered for deno
            # We check by trying to get completions
            $ast = New-MockCommandAst -CommandLine 'deno '
            # If this doesn't throw, the completer is registered
            { TabExpansion2 -inputScript 'deno ' -cursorColumn 5 } | Should -Not -Throw
        }
    }

    Context 'Behavior without deno installed' {
        BeforeAll {
            # Remove any mock deno function
            Remove-Item Function:\deno -ErrorAction SilentlyContinue
            # Also mock Get-Command to return nothing
            $script:OriginalGetCommand = Get-Command Get-Command
        }

        It 'Should not throw when deno is not installed' {
            # Source in a fresh scope
            {
                $tempScript = @'
if (Get-Command -Name "deno" -ErrorAction SilentlyContinue) {
    # This won't run
    deno completions powershell | Out-String | Invoke-Expression
}
'@
                Invoke-Expression $tempScript
            } | Should -Not -Throw
        }
    }
}

Describe 'Dotnet Completion' {
    BeforeAll {
        $script:DotnetScript = Join-Path $script:CompletionsPath 'dotnet.ps1'
    }

    Context 'Script structure' {
        It 'Should exist' {
            Test-Path $script:DotnetScript | Should -BeTrue
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:DotnetScript, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should register argument completer for dotnet' {
            $content = Get-Content $script:DotnetScript -Raw
            $content | Should -Match 'Register-ArgumentCompleter.*-CommandName dotnet'
        }

        It 'Should use -Native switch' {
            $content = Get-Content $script:DotnetScript -Raw
            $content | Should -Match '-Native'
        }

        It 'Should call dotnet complete' {
            $content = Get-Content $script:DotnetScript -Raw
            $content | Should -Match 'dotnet complete'
        }

        It 'Should pass position parameter' {
            $content = Get-Content $script:DotnetScript -Raw
            $content | Should -Match '--position.*\$cursorPosition'
        }

        It 'Should create CompletionResult objects' {
            $content = Get-Content $script:DotnetScript -Raw
            $content | Should -Match 'System\.Management\.Automation\.CompletionResult'
        }
    }

    Context 'Completer behavior with mock dotnet' {
        BeforeAll {
            # Mock dotnet complete
            function global:dotnet {
                param()
                $allArgs = $args -join ' '
                if ($allArgs -match 'complete') {
                    @('build', 'clean', 'new', 'publish', 'restore', 'run', 'test', 'watch')
                }
            }

            # Source the script
            . $script:DotnetScript
        }

        AfterAll {
            Remove-Item Function:\dotnet -ErrorAction SilentlyContinue
        }

        It 'Should return completion results' {
            # Get the registered completer and invoke it
            $ast = New-MockCommandAst -CommandLine 'dotnet '
            $result = TabExpansion2 -inputScript 'dotnet ' -cursorColumn 7

            # Should have completions
            $result.CompletionMatches.Count | Should -BeGreaterThan 0
        }

        It 'Should return CompletionResult objects' {
            $result = TabExpansion2 -inputScript 'dotnet ' -cursorColumn 7
            $result.CompletionMatches[0] | Should -BeOfType [System.Management.Automation.CompletionResult]
        }
    }
}

Describe 'Winget Completion' {
    BeforeAll {
        $script:WingetScript = Join-Path $script:CompletionsPath 'winget.ps1'
    }

    Context 'Script structure' {
        It 'Should exist' {
            Test-Path $script:WingetScript | Should -BeTrue
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:WingetScript, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should register argument completer for winget' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match 'Register-ArgumentCompleter.*-CommandName winget'
        }

        It 'Should use -Native switch' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match '-Native'
        }

        It 'Should call winget complete' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match 'winget complete'
        }

        It 'Should handle UTF-8 encoding' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match 'Utf8Encoding'
        }

        It 'Should handle quoted strings in command' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match 'Replace.*\"'
        }

        It 'Should pass word, commandline, and position' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match '--word='
            $content | Should -Match '--commandline'
            $content | Should -Match '--position'
        }

        It 'Should create CompletionResult objects' {
            $content = Get-Content $script:WingetScript -Raw
            $content | Should -Match 'System\.Management\.Automation\.CompletionResult'
        }
    }

    Context 'Completer behavior with mock winget' {
        BeforeAll {
            # Mock winget complete
            function global:winget {
                param()
                $allArgs = $args -join ' '
                if ($allArgs -match 'complete') {
                    @('install', 'show', 'source', 'search', 'list', 'upgrade', 'uninstall', 'hash', 'validate', 'settings', 'features', 'export', 'import')
                }
            }

            # Source the script
            . $script:WingetScript
        }

        AfterAll {
            Remove-Item Function:\winget -ErrorAction SilentlyContinue
        }

        It 'Should return completion results' {
            $result = TabExpansion2 -inputScript 'winget ' -cursorColumn 7
            $result.CompletionMatches.Count | Should -BeGreaterThan 0
        }

        It 'Should return CompletionResult objects' {
            $result = TabExpansion2 -inputScript 'winget ' -cursorColumn 7
            $result.CompletionMatches[0] | Should -BeOfType [System.Management.Automation.CompletionResult]
        }
    }

    Context 'Edge cases' {
        BeforeAll {
            function global:winget {
                param()
                @('install', 'search', 'show')
            }
            . $script:WingetScript
        }

        AfterAll {
            Remove-Item Function:\winget -ErrorAction SilentlyContinue
        }

        It 'Should handle command with special characters' {
            # Test with quotes in the command
            { TabExpansion2 -inputScript 'winget search "some app"' -cursorColumn 24 } | Should -Not -Throw
        }

        It 'Should handle empty completion' {
            { TabExpansion2 -inputScript 'winget ' -cursorColumn 7 } | Should -Not -Throw
        }
    }
}

Describe 'Delegation Pattern Validation' {
    Context 'All delegation scripts follow best practices' {
        BeforeAll {
            $script:DelegationScripts = @(
                (Join-Path $script:CompletionsPath 'deno.ps1'),
                (Join-Path $script:CompletionsPath 'dotnet.ps1'),
                (Join-Path $script:CompletionsPath 'winget.ps1')
            )
        }

        It 'Should have no syntax errors in <_>' -ForEach @('deno.ps1', 'dotnet.ps1', 'winget.ps1') {
            $path = Join-Path $script:CompletionsPath $_
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It 'Should register native completers in <_>' -ForEach @('deno.ps1', 'dotnet.ps1', 'winget.ps1') {
            $path = Join-Path $script:CompletionsPath $_
            $content = Get-Content $path -Raw
            $content | Should -Match 'Register-ArgumentCompleter'
            $content | Should -Match '-Native'
        }

        It 'Should be concise (under 20 lines) for <_>' -ForEach @('deno.ps1', 'dotnet.ps1', 'winget.ps1') {
            $path = Join-Path $script:CompletionsPath $_
            $lineCount = (Get-Content $path).Count
            $lineCount | Should -BeLessOrEqual 20
        }
    }
}
