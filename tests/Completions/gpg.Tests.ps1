#Requires -Modules Pester

BeforeAll {
    # Navigate from tests/Completions to project root, then to src
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot 'src'
    $script:UtilsPath = Join-Path $script:ModulePath 'Utils.ps1'
    $script:CompletionScript = Join-Path $script:ModulePath 'Completions' 'gpg.ps1'

    # Source Utils first (required by gpg.ps1)
    . $script:UtilsPath

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

Describe 'GPG Completion' {
    BeforeAll {
        # Mock gpg commands
        function global:gpg {
            param(
                [switch]$Private:ListKeys,
                [switch]$Private:DumpOptions,
                [string]$Private:KeyidFormat
            )

            # Check actual parameters passed
            $allArgs = $args -join ' '

            if ($allArgs -match '--list-keys') {
                # Return mock key list
                @(
                    'pub   rsa4096/ABC123DEF456 2023-01-01 [SC]',
                    'uid                 [ultimate] Test User <test@example.com>',
                    'uid                 [ultimate] Another Name <another@example.com>',
                    'sub   rsa4096/789GHI012JKL 2023-01-01 [E]',
                    '',
                    'pub   rsa4096/MNO345PQR678 2023-06-15 [SC]',
                    'uid                 [ultimate] Second User <second@example.com>'
                )
            }
            elseif ($allArgs -match '--dump-options') {
                # Return mock options
                @(
                    '--armor',
                    '--output',
                    '--recipient',
                    '--sign',
                    '--encrypt',
                    '--decrypt',
                    '--verify',
                    '--list-keys',
                    '--export',
                    '--import',
                    '--keyserver',
                    '--verbose',
                    '--quiet'
                )
            }
            else {
                @()
            }
        }

        # Now source the completion script
        . $script:CompletionScript

        $script:GpgCompleter = $gpgScriptBlock
        $script:GpgvCompleter = $gpgvScriptBlock
    }

    AfterAll {
        # Clean up mock
        Remove-Item Function:\gpg -ErrorAction SilentlyContinue
    }

    Context 'Get-KeyCompletions function' {
        It 'Should return email addresses from keys' {
            $result = Get-KeyCompletions
            $result | Should -Contain 'test@example.com'
            $result | Should -Contain 'another@example.com'
            $result | Should -Contain 'second@example.com'
        }

        It 'Should return usernames from keys' {
            $result = Get-KeyCompletions
            $result | Should -Contain 'Test User'
            $result | Should -Contain 'Another Name'
            $result | Should -Contain 'Second User'
        }

        It 'Should return key IDs' {
            $result = Get-KeyCompletions
            $result | Should -Contain 'ABC123DEF456'
            $result | Should -Contain 'MNO345PQR678'
        }

        It 'Should not contain duplicate entries' {
            $result = Get-KeyCompletions
            $uniqueResult = $result | Select-Object -Unique
            $result.Count | Should -Be $uniqueResult.Count
        }
    }

    Context 'GPG option completion' {
        BeforeAll {
            function Invoke-GpgCompleter {
                param(
                    [string]$CommandLine,
                    [string]$WordToComplete = '',
                    [int]$CursorPosition = -1
                )

                if ($CursorPosition -eq -1) {
                    $CursorPosition = $CommandLine.Length
                }

                $ast = New-MockCommandAst -CommandLine $CommandLine
                & $script:GpgCompleter $WordToComplete $ast $CursorPosition
            }
        }

        It 'Should complete options when starting with dash' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --' -WordToComplete '--'
            $result | Should -Contain '--armor'
            $result | Should -Contain '--output'
            $result | Should -Contain '--recipient'
        }

        It 'Should complete options starting with --ar' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --ar' -WordToComplete '--ar'
            $result | Should -Contain '--armor'
            $result | Should -Not -Contain '--output'
        }

        It 'Should complete options after command name (gpg)' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg ' -WordToComplete ''
            # Should still return options when prev is like gpg*
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should filter options by prefix' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --e' -WordToComplete '--e'
            $result | Should -Contain '--encrypt'
            $result | Should -Contain '--export'
            $result | Should -Not -Contain '--armor'
        }

        It 'Should handle single dash options' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg -' -WordToComplete '-'
            $result.Count | Should -BeGreaterThan 0
        }
    }

    Context 'GPG key recipient completion' {
        BeforeAll {
            function Invoke-GpgCompleter {
                param(
                    [string]$CommandLine,
                    [string]$WordToComplete = '',
                    [int]$CursorPosition = -1
                )

                if ($CursorPosition -eq -1) {
                    $CursorPosition = $CommandLine.Length
                }

                $ast = New-MockCommandAst -CommandLine $CommandLine
                & $script:GpgCompleter $WordToComplete $ast $CursorPosition
            }
        }

        It 'Should complete recipients after --recipient' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --recipient ' -WordToComplete ''
            $result | Should -Contain 'test@example.com'
            $result | Should -Contain 'Test User'
        }

        It 'Should complete recipients after -r' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg -r ' -WordToComplete ''
            $result | Should -Contain 'test@example.com'
        }

        It 'Should filter recipients by prefix' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --recipient test' -WordToComplete 'test'
            $result | Should -Contain 'test@example.com'
            $result | Should -Not -Contain 'second@example.com'
        }

        It 'Should complete after --export' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --export ' -WordToComplete ''
            $result | Should -Contain 'test@example.com'
            $result | Should -Contain 'ABC123DEF456'
        }

        It 'Should complete after --sign-key' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --sign-key ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should complete after --edit-key' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --edit-key ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should complete after --lsign-key' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --lsign-key ' -WordToComplete ''
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'GPGv completion' {
        BeforeAll {
            function Invoke-GpgvCompleter {
                param(
                    [string]$CommandLine,
                    [string]$WordToComplete = '',
                    [int]$CursorPosition = -1
                )

                if ($CursorPosition -eq -1) {
                    $CursorPosition = $CommandLine.Length
                }

                $ast = New-MockCommandAst -CommandLine $CommandLine
                & $script:GpgvCompleter $WordToComplete $ast $CursorPosition
            }
        }

        It 'Should complete gpgv options starting with dash' {
            $result = Invoke-GpgvCompleter -CommandLine 'gpgv -' -WordToComplete '-'
            $result | Should -Contain '--verbose'
            $result | Should -Contain '--quiet'
            $result | Should -Contain '--keyring'
        }

        It 'Should complete --output option' {
            $result = Invoke-GpgvCompleter -CommandLine 'gpgv --o' -WordToComplete '--o'
            $result | Should -Contain '--output'
        }

        It 'Should complete --status-fd option' {
            $result = Invoke-GpgvCompleter -CommandLine 'gpgv --st' -WordToComplete '--st'
            $result | Should -Contain '--status-fd'
        }

        It 'Should complete all gpgv-specific options' {
            $result = Invoke-GpgvCompleter -CommandLine 'gpgv --' -WordToComplete '--'
            $result | Should -Contain '--verbose'
            $result | Should -Contain '--quiet'
            $result | Should -Contain '--keyring'
            $result | Should -Contain '--output'
            $result | Should -Contain '--ignore-time-conflict'
            $result | Should -Contain '--status-fd'
            $result | Should -Contain '--weak-digest'
        }

        It 'Should not complete when not starting with dash' {
            $result = Invoke-GpgvCompleter -CommandLine 'gpgv file' -WordToComplete 'file'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Edge cases' {
        BeforeAll {
            function Invoke-GpgCompleter {
                param(
                    [string]$CommandLine,
                    [string]$WordToComplete = '',
                    [int]$CursorPosition = -1
                )

                if ($CursorPosition -eq -1) {
                    $CursorPosition = $CommandLine.Length
                }

                $ast = New-MockCommandAst -CommandLine $CommandLine
                & $script:GpgCompleter $WordToComplete $ast $CursorPosition
            }
        }

        It 'Should handle empty word to complete after gpg' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg ' -WordToComplete ''
            # Should return options since prev is 'gpg'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle multiple options before completion' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --armor --output file.asc --' -WordToComplete '--'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should handle key ID completion with partial match' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --recipient ABC' -WordToComplete 'ABC'
            $result | Should -Contain 'ABC123DEF456'
        }

        It 'Should handle username with spaces in completion' {
            $result = Invoke-GpgCompleter -CommandLine 'gpg --recipient Test' -WordToComplete 'Test'
            $result | Should -Contain 'Test User'
        }
    }
}
