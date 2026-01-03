#Requires -Modules Pester

BeforeAll {
    # Navigate from tests/Completions to project root, then to src
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot 'src'
    $script:CompletionScript = Join-Path $script:ModulePath 'Completions' 'scoop.ps1'

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

    # Set up mock scoop environment
    $script:TempScoopDir = Join-Path $env:TEMP "PwshCompleteScoop_$(Get-Random)"
    $script:TempAppsDir = Join-Path $script:TempScoopDir 'apps'
    $script:TempBucketsDir = Join-Path $script:TempScoopDir 'buckets'

    # Create directories
    New-Item -ItemType Directory -Path $script:TempAppsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TempBucketsDir -Force | Out-Null

    # Create mock installed apps
    @('7zip', 'git', 'nodejs', 'python', 'vscode') | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $script:TempAppsDir $_) -Force | Out-Null
    }

    # Create mock buckets with manifests
    $mainBucket = Join-Path $script:TempBucketsDir 'main' 'bucket'
    $extrasBucket = Join-Path $script:TempBucketsDir 'extras' 'bucket'
    New-Item -ItemType Directory -Path $mainBucket -Force | Out-Null
    New-Item -ItemType Directory -Path $extrasBucket -Force | Out-Null

    # Create mock manifests
    @('7zip.json', 'git.json', 'nodejs.json', 'python.json', 'curl.json', 'wget.json') | ForEach-Object {
        New-Item -ItemType File -Path (Join-Path $mainBucket $_) -Force | Out-Null
    }
    @('vscode.json', 'firefox.json', 'chrome.json', 'notepadplusplus.json') | ForEach-Object {
        New-Item -ItemType File -Path (Join-Path $extrasBucket $_) -Force | Out-Null
    }

    # Create mock config
    $script:TempConfigDir = Join-Path $env:TEMP "PwshCompleteConfig_$(Get-Random)"
    $script:TempConfigScoopDir = Join-Path $script:TempConfigDir 'scoop'
    New-Item -ItemType Directory -Path $script:TempConfigScoopDir -Force | Out-Null

    $mockConfig = @{
        alias = @{
            i = 'install'
            u = 'update'
            rm = 'uninstall'
        }
    } | ConvertTo-Json
    Set-Content -Path (Join-Path $script:TempConfigScoopDir 'config.json') -Value $mockConfig

    # Set environment variables
    $script:OriginalScoop = $env:SCOOP
    $script:OriginalXdgConfig = $env:XDG_CONFIG_HOME
    $env:SCOOP = $script:TempScoopDir
    $env:XDG_CONFIG_HOME = $script:TempConfigDir

    # Source the completion script
    . $script:CompletionScript
}

AfterAll {
    # Restore environment
    $env:SCOOP = $script:OriginalScoop
    $env:XDG_CONFIG_HOME = $script:OriginalXdgConfig

    # Clean up temp directories
    @($script:TempScoopDir, $script:TempConfigDir) | ForEach-Object {
        if (Test-Path $_) {
            Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Scoop Completion' {
    BeforeAll {
        function Invoke-ScoopCompleter {
            param(
                [string]$CommandLine,
                [string]$WordToComplete = '',
                [int]$CursorPosition = -1
            )

            if ($CursorPosition -eq -1) {
                $CursorPosition = $CommandLine.Length
            }

            $ast = New-MockCommandAst -CommandLine $CommandLine
            & $scriptBlock $WordToComplete $ast $CursorPosition
        }
    }

    Context 'Command completion' {
        It 'Should complete all scoop commands' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop ' -WordToComplete ''
            $result | Should -Contain 'install'
            $result | Should -Contain 'uninstall'
            $result | Should -Contain 'update'
            $result | Should -Contain 'search'
            $result | Should -Contain 'bucket'
            $result | Should -Contain 'cache'
        }

        It 'Should complete commands starting with "in"' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop in' -WordToComplete 'in'
            $result | Should -Contain 'install'
            $result | Should -Contain 'info'
            $result | Should -Contain 'import'
            $result | Should -Not -Contain 'uninstall'
        }

        It 'Should complete commands starting with "un"' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop un' -WordToComplete 'un'
            $result | Should -Contain 'uninstall'
            $result | Should -Contain 'unhold'
            $result | Should -Not -Contain 'install'
        }

        It 'Should complete help command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop h' -WordToComplete 'h'
            $result | Should -Contain 'help'
            $result | Should -Contain 'hold'
            $result | Should -Contain 'home'
        }

        It 'Should include aliases in completions' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop ' -WordToComplete ''
            # Aliases defined in config: i, u, rm
            $result | Should -Contain 'i'
            $result | Should -Contain 'u'
            $result | Should -Contain 'rm'
        }
    }

    Context 'Subcommand completion' {
        It 'Should complete bucket subcommands' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop bucket ' -WordToComplete ''
            $result | Should -Contain 'add'
            $result | Should -Contain 'list'
            $result | Should -Contain 'known'
            $result | Should -Contain 'rm'
        }

        It 'Should complete cache subcommands' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop cache ' -WordToComplete ''
            $result | Should -Contain 'rm'
            $result | Should -Contain 'show'
        }

        It 'Should complete alias subcommands' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop alias ' -WordToComplete ''
            $result | Should -Contain 'add'
            $result | Should -Contain 'list'
            $result | Should -Contain 'rm'
        }

        It 'Should complete shim subcommands' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop shim ' -WordToComplete ''
            $result | Should -Contain 'add'
            $result | Should -Contain 'list'
            $result | Should -Contain 'rm'
            $result | Should -Contain 'info'
            $result | Should -Contain 'alter'
        }

        It 'Should complete config subcommands and params' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config ' -WordToComplete ''
            $result | Should -Contain 'rm'
            $result | Should -Contain 'proxy'
            $result | Should -Contain 'aria2-enabled'
        }

        It 'Should filter subcommands by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop bucket a' -WordToComplete 'a'
            $result | Should -Contain 'add'
            $result | Should -Not -Contain 'list'
        }
    }

    Context 'Package name completion for install' {
        It 'Should complete remote package names for install' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install ' -WordToComplete ''
            $result | Should -Contain '7zip'
            $result | Should -Contain 'git'
            $result | Should -Contain 'vscode'
            $result | Should -Contain 'firefox'
        }

        It 'Should filter packages by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install v' -WordToComplete 'v'
            $result | Should -Contain 'vscode'
            $result | Should -Not -Contain 'git'
        }

        It 'Should complete for info command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop info ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should complete for home command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop home ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should complete for depends command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop depends ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Package name completion for uninstall/update' {
        It 'Should complete local package names for uninstall' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop uninstall ' -WordToComplete ''
            $result | Should -Contain '7zip'
            $result | Should -Contain 'git'
            $result | Should -Contain 'python'
            # Should not contain remote-only packages
            $result | Should -Not -Contain 'firefox'
        }

        It 'Should complete local packages for cleanup' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop cleanup ' -WordToComplete ''
            $result | Should -Contain 'git'
            $result | Should -Contain 'nodejs'
        }

        It 'Should complete local packages for update' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop update ' -WordToComplete ''
            $result | Should -Contain 'git'
            $result | Should -Contain 'vscode'
        }

        It 'Should complete local packages for hold' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop hold ' -WordToComplete ''
            $result | Should -Contain '7zip'
        }

        It 'Should complete local packages for unhold' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop unhold ' -WordToComplete ''
            $result | Should -Contain 'python'
        }

        It 'Should complete for prefix command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop prefix ' -WordToComplete ''
            $result | Should -Contain 'git'
        }

        It 'Should complete for reset command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop reset ' -WordToComplete ''
            $result | Should -Contain 'nodejs'
        }
    }

    Context 'Download and cat command completion' {
        It 'Should complete both local and remote packages for download' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop download ' -WordToComplete ''
            # Should contain both local and remote packages
            $result | Should -Contain 'git'  # local
            $result | Should -Contain 'firefox'  # remote only
        }

        It 'Should complete for cat command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop cat ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Long parameter completion' {
        It 'Should complete --global for install' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install --' -WordToComplete '--'
            $result | Should -Contain '--global'
            $result | Should -Contain '--independent'
            $result | Should -Contain '--no-cache'
        }

        It 'Should complete --purge for uninstall' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop uninstall --' -WordToComplete '--'
            $result | Should -Contain '--global'
            $result | Should -Contain '--purge'
        }

        It 'Should complete update parameters' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop update --' -WordToComplete '--'
            $result | Should -Contain '--force'
            $result | Should -Contain '--global'
            $result | Should -Contain '--all'
            $result | Should -Contain '--quiet'
        }

        It 'Should filter long params by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install --g' -WordToComplete '--g'
            $result | Should -Contain '--global'
            $result | Should -Not -Contain '--independent'
        }
    }

    Context 'Short parameter completion' {
        It 'Should complete short params for install' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install -' -WordToComplete '-'
            $result | Should -Contain '-g'
            $result | Should -Contain '-i'
            $result | Should -Contain '-k'
        }

        It 'Should complete short params for update' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop update -' -WordToComplete '-'
            $result | Should -Contain '-f'
            $result | Should -Contain '-g'
            $result | Should -Contain '-q'
            $result | Should -Contain '-a'
        }
    }

    Context 'Parameter value completion' {
        It 'Should complete arch values after --arch' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install --arch ' -WordToComplete ''
            $result | Should -Contain '32bit'
            $result | Should -Contain '64bit'
        }

        It 'Should complete arch values after -a' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install -a ' -WordToComplete ''
            $result | Should -Contain '32bit'
            $result | Should -Contain '64bit'
        }

        It 'Should filter arch values by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install --arch 3' -WordToComplete '3'
            $result | Should -Contain '32bit'
            $result | Should -Not -Contain '64bit'
        }
    }

    Context 'Config parameter value completion' {
        It 'Should complete config boolean values' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config use_lessmsi ' -WordToComplete ''
            $result | Should -Contain 'true'
            $result | Should -Contain 'false'
        }

        It 'Should complete scoop_branch values' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config scoop_branch ' -WordToComplete ''
            $result | Should -Contain 'master'
            $result | Should -Contain 'develop'
        }

        It 'Should complete default_architecture values' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config default_architecture ' -WordToComplete ''
            $result | Should -Contain '32bit'
            $result | Should -Contain '64bit'
        }

        It 'Should complete shim values' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config shim ' -WordToComplete ''
            $result | Should -Contain 'kiennq'
            $result | Should -Contain 'scoopcs'
            $result | Should -Contain '71'
        }

        It 'Should complete cat_style values' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config cat_style ' -WordToComplete ''
            $result | Should -Contain 'default'
            $result | Should -Contain 'auto'
            $result | Should -Contain 'full'
            $result | Should -Contain 'plain'
        }
    }

    Context 'Config rm completion' {
        It 'Should complete config param names for rm' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config rm ' -WordToComplete ''
            $result | Should -Contain 'proxy'
            $result | Should -Contain 'aria2-enabled'
            $result | Should -Contain 'use_lessmsi'
        }

        It 'Should filter config params by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop config rm aria' -WordToComplete 'aria'
            $result | Should -Contain 'aria2-enabled'
            $result | Should -Contain 'aria2-warning-enabled'
        }
    }

    Context 'Bucket operations' {
        BeforeAll {
            # Mock scoop bucket commands
            function global:scoop {
                param()
                $allArgs = $args -join ' '
                if ($allArgs -match 'bucket list') {
                    @('main', 'extras')
                }
                elseif ($allArgs -match 'bucket known') {
                    @('main', 'extras', 'versions', 'nirsoft', 'php', 'nerd-fonts', 'nonportable', 'java', 'games')
                }
                else {
                    @()
                }
            }
        }

        AfterAll {
            Remove-Item Function:\scoop -ErrorAction SilentlyContinue
        }

        It 'Should complete local buckets for bucket rm' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop bucket rm ' -WordToComplete ''
            $result | Should -Contain 'main'
            $result | Should -Contain 'extras'
        }

        It 'Should complete known buckets for bucket add' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop bucket add ' -WordToComplete ''
            $result | Should -Contain 'main'
            $result | Should -Contain 'extras'
            $result | Should -Contain 'versions'
            $result | Should -Contain 'nerd-fonts'
        }
    }

    Context 'Alias operations' {
        It 'Should complete alias names for alias rm' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop alias rm ' -WordToComplete ''
            $result | Should -Contain 'i'
            $result | Should -Contain 'u'
            $result | Should -Contain 'rm'
        }

        It 'Should filter aliases by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop alias rm r' -WordToComplete 'r'
            $result | Should -Contain 'rm'
            $result | Should -Not -Contain 'i'
        }
    }

    Context 'Help command completion' {
        It 'Should complete command names for help' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop help ' -WordToComplete ''
            $result | Should -Contain 'install'
            $result | Should -Contain 'bucket'
            $result | Should -Contain 'update'
            # Help should not include aliases
            $result | Should -Not -Contain 'i'
        }

        It 'Should filter help topics by prefix' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop help b' -WordToComplete 'b'
            $result | Should -Contain 'bucket'
            $result | Should -Not -Contain 'install'
        }
    }

    Context 'Edge cases' {
        It 'Should handle empty input after scoop' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop ' -WordToComplete ''
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Should handle trailing space properly' {
            # Testing that trailing space triggers next completion
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install git ' -WordToComplete ''
            # After a package, should still allow more packages
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle multiple packages in install' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install git p' -WordToComplete 'p'
            $result | Should -Contain 'python'
        }

        It 'Should handle mixed flags and packages' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop install -g git ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle virustotal command' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop virustotal ' -WordToComplete ''
            $result | Should -Contain 'git'
            $result | Should -Contain '7zip'
        }

        It 'Should handle virustotal long params' {
            $result = Invoke-ScoopCompleter -CommandLine 'scoop virustotal --' -WordToComplete '--'
            $result | Should -Contain '--arch'
            $result | Should -Contain '--scan'
            $result | Should -Contain '--no-depends'
        }
    }

    Context 'ScoopTabExpansion function' {
        It 'Should handle complex command patterns without throwing' {
            # After specifying arch and a package, should not crash
            { ScoopTabExpansion 'install --arch 64bit git' } | Should -Not -Throw
        }

        It 'Should return sorted results for commands' {
            $result = ScoopTabExpansion ''
            # Results should be sorted
            $sorted = $result | Sort-Object
            # First few should match sorted order
            if ($result.Count -gt 1) {
                $result[0] | Should -Be $sorted[0]
            }
        }
    }
}
