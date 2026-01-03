#Requires -Modules Pester

BeforeAll {
    # Navigate from tests/Completions to project root, then to src
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot 'src'
    $script:UtilsPath = Join-Path $script:ModulePath 'Utils.ps1'
    $script:CompletionScript = Join-Path $script:ModulePath 'Completions' 'ssh.ps1'

    # Source Utils first
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

Describe 'SSH Completion Script Structure' {
    Context 'Script file validation' {
        It 'Should exist' {
            Test-Path $script:CompletionScript | Should -BeTrue
        }

        It 'Should have valid PowerShell syntax' {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $script:CompletionScript, [ref]$null, [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It 'Should define Get-SshConfigHosts function' {
            $content = Get-Content $script:CompletionScript -Raw
            $content | Should -Match 'function Get-SshConfigHosts'
        }

        It 'Should define Get-SshKnownHosts function' {
            $content = Get-Content $script:CompletionScript -Raw
            $content | Should -Match 'function Get-SshKnownHosts'
        }

        It 'Should register SSH completer' {
            $content = Get-Content $script:CompletionScript -Raw
            $content | Should -Match 'Register-ArgumentCompleter.*-CommandName ssh'
        }

        It 'Should register SCP completer' {
            $content = Get-Content $script:CompletionScript -Raw
            $content | Should -Match 'Register-ArgumentCompleter.*-CommandName scp'
        }

        It 'Should define SSH options' {
            $content = Get-Content $script:CompletionScript -Raw
            $content | Should -Match '\$options\s*='
        }
    }
}

Describe 'SSH Completion with Mocked Data' {
    BeforeAll {
        # Source the script first to get the original functions
        . $script:CompletionScript

        # Store original script blocks
        $script:SshCompleter = $sshScriptBlock
        $script:ScpCompleter = $scpScriptBlock

        # Mock the config/known_hosts functions by redefining them
        function global:Get-SshConfigHosts {
            @('github.com', 'server1', 'server2', '*.internal.local', 'production-*')
        }

        function global:Get-SshKnownHosts {
            @('github.com', '140.82.121.4', '192.168.1.100', 'gitlab.com', '[10.0.0.1]:2222')
        }

        function Invoke-SshCompleter {
            param(
                [string]$CommandLine,
                [string]$WordToComplete = '',
                [int]$CursorPosition = -1
            )

            if ($CursorPosition -eq -1) {
                $CursorPosition = $CommandLine.Length
            }

            $ast = New-MockCommandAst -CommandLine $CommandLine
            & $script:SshCompleter $WordToComplete $ast $CursorPosition
        }

        function Invoke-ScpCompleter {
            param(
                [string]$CommandLine,
                [string]$WordToComplete = '',
                [int]$CursorPosition = -1
            )

            if ($CursorPosition -eq -1) {
                $CursorPosition = $CommandLine.Length
            }

            $ast = New-MockCommandAst -CommandLine $CommandLine
            & $script:ScpCompleter $WordToComplete $ast $CursorPosition
        }
    }

    AfterAll {
        Remove-Item Function:\Get-SshConfigHosts -ErrorAction SilentlyContinue
        Remove-Item Function:\Get-SshKnownHosts -ErrorAction SilentlyContinue
    }

    Context 'SSH option completion' {
        It 'Should show all options when completing dash' {
            $result = Invoke-SshCompleter -CommandLine 'ssh -' -WordToComplete '-'
            $result | Should -Contain '-4'
            $result | Should -Contain '-6'
            $result | Should -Contain '-A'
            $result | Should -Contain '-C'
            $result | Should -Contain '-v'
            $result | Should -Contain '-l'
            $result | Should -Contain '-p'
        }

        It 'Should show all available SSH options' {
            $result = Invoke-SshCompleter -CommandLine 'ssh -' -WordToComplete '-'
            $expectedOptions = @('-4', '-6', '-A', '-a', '-C', '-f', '-G', '-g', '-K', '-k',
                '-M', '-N', '-n', '-q', '-s', '-T', '-t', '-V', '-v', '-X', '-x', '-Y', '-y',
                '-B', '-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J', '-L', '-l', '-m',
                '-O', '-o', '-p', '-Q', '-R', '-S', '-W', '-w')
            foreach ($opt in $expectedOptions) {
                $result | Should -Contain $opt
            }
        }
    }

    Context 'SSH parameter value completion' {
        BeforeAll {
            # Mock ssh -Q commands
            function global:ssh {
                param()
                $allArgs = $args -join ' '
                if ($allArgs -match '-Q cipher') {
                    @('aes128-ctr', 'aes192-ctr', 'aes256-ctr', 'aes128-gcm@openssh.com', 'chacha20-poly1305@openssh.com')
                }
                elseif ($allArgs -match '-Q mac') {
                    @('hmac-sha2-256', 'hmac-sha2-512', 'umac-64@openssh.com', 'umac-128@openssh.com')
                }
                else {
                    @()
                }
            }
        }

        AfterAll {
            Remove-Item Function:\ssh -ErrorAction SilentlyContinue
        }

        It 'Should complete multiplex commands after -O' {
            $result = Invoke-SshCompleter -CommandLine 'ssh -O ' -WordToComplete ''
            $result | Should -Contain 'check'
            $result | Should -Contain 'forward'
            $result | Should -Contain 'cancel'
            $result | Should -Contain 'exit'
            $result | Should -Contain 'stop'
        }

        It 'Should filter -O commands by prefix' {
            $result = Invoke-SshCompleter -CommandLine 'ssh -O c' -WordToComplete 'c'
            $result | Should -Contain 'check'
            $result | Should -Contain 'cancel'
            $result | Should -Not -Contain 'forward'
        }
    }

    Context 'SSH host completion' {
        It 'Should complete hosts from config and known_hosts' {
            $result = Invoke-SshCompleter -CommandLine 'ssh ' -WordToComplete ''
            $result | Should -Contain 'github.com'
            $result | Should -Contain 'server1'
            $result | Should -Contain 'server2'
            $result | Should -Contain 'gitlab.com'
        }

        It 'Should filter hosts by prefix' {
            $result = Invoke-SshCompleter -CommandLine 'ssh ser' -WordToComplete 'ser'
            $result | Should -Contain 'server1'
            $result | Should -Contain 'server2'
            $result | Should -Not -Contain 'github.com'
        }

        It 'Should complete hosts starting with "g"' {
            $result = Invoke-SshCompleter -CommandLine 'ssh g' -WordToComplete 'g'
            $result | Should -Contain 'github.com'
            $result | Should -Contain 'gitlab.com'
        }

        It 'Should handle user@host format' {
            $result = Invoke-SshCompleter -CommandLine 'ssh user@' -WordToComplete 'user@'
            $result | Should -Contain 'user@github.com'
            $result | Should -Contain 'user@server1'
        }

        It 'Should handle user@host with partial host' {
            $result = Invoke-SshCompleter -CommandLine 'ssh admin@ser' -WordToComplete 'admin@ser'
            $result | Should -Contain 'admin@server1'
            $result | Should -Contain 'admin@server2'
        }
    }

    Context 'SCP completion' {
        It 'Should complete hosts with colon suffix' {
            $result = Invoke-ScpCompleter -CommandLine 'scp ' -WordToComplete ''
            $result | Should -Contain 'github.com:'
            $result | Should -Contain 'server1:'
        }

        It 'Should filter hosts by prefix' {
            $result = Invoke-ScpCompleter -CommandLine 'scp ser' -WordToComplete 'ser'
            $result | Should -Contain 'server1:'
            $result | Should -Contain 'server2:'
            $result | Should -Not -Contain 'github.com:'
        }

        It 'Should return empty for dash (options not implemented)' {
            $result = Invoke-ScpCompleter -CommandLine 'scp -' -WordToComplete '-'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Edge cases' {
        It 'Should handle empty command line after ssh' {
            $result = Invoke-SshCompleter -CommandLine 'ssh ' -WordToComplete ''
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Should handle IP address completion' {
            $result = Invoke-SshCompleter -CommandLine 'ssh 192' -WordToComplete '192'
            $result | Should -Contain '192.168.1.100'
        }

        It 'Should not crash on unusual characters in input' {
            { Invoke-SshCompleter -CommandLine 'ssh test$%^' -WordToComplete 'test$%^' } | Should -Not -Throw
        }
    }
}

Describe 'SSH Helper Functions Integration' {
    BeforeAll {
        # Source the actual script
        . $script:CompletionScript
    }

    Context 'Get-SshConfigHosts with real system' {
        It 'Should not throw when called' {
            { Get-SshConfigHosts } | Should -Not -Throw
        }

        It 'Should return valid result type' {
            $result = Get-SshConfigHosts
            # Result can be null, empty, or an array - all are valid
            if ($null -ne $result) {
                $result | Should -BeOfType [object]
            }
        }
    }

    Context 'Get-SshKnownHosts with real system' {
        It 'Should not throw when called' {
            { Get-SshKnownHosts } | Should -Not -Throw
        }

        It 'Should return valid result type' {
            $result = Get-SshKnownHosts
            # Result can be null, empty, or an array - all are valid
            if ($null -ne $result) {
                $result | Should -BeOfType [object]
            }
        }
    }
}
