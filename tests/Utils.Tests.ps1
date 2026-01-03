#Requires -Modules Pester

BeforeAll {
    $script:ProjectRoot = Split-Path $PSScriptRoot -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot 'src'
    . (Join-Path $script:ModulePath 'Utils.ps1')

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

Describe 'Get-PrevAst Function' {
    Context 'Basic functionality' {
        It 'Should return the previous token when cursor is at end' {
            $ast = New-MockCommandAst 'ssh -l user'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 11
            # When cursor is at the end, should return the last element
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should return last element when cursor is beyond command length' {
            $ast = New-MockCommandAst 'ssh -l user'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 100
            $result | Should -Be 'user'
        }

        It 'Should not throw for valid input' {
            $ast = New-MockCommandAst 'ssh -l user'
            { Get-PrevAst -commandAst $ast -cursorPosition 8 } | Should -Not -Throw
        }
    }

    Context 'Flag completion scenarios' {
        It 'Should handle cursor after flag with value' {
            $ast = New-MockCommandAst 'gpg --export keyid'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 18
            # At end, should return last element
            $result | Should -Be 'keyid'
        }

        It 'Should handle long option flags' {
            $ast = New-MockCommandAst 'gpg --recipient test@example.com'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 32
            $result | Should -Be 'test@example.com'
        }
    }

    Context 'Command with multiple elements' {
        It 'Should handle commands with multiple arguments' {
            $ast = New-MockCommandAst 'ssh -v -C server'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 16
            $result | Should -Be 'server'
        }

        It 'Should handle combined short parameters' {
            $ast = New-MockCommandAst 'ssh -vvv host'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 13
            $result | Should -Be 'host'
        }
    }

    Context 'Edge cases' {
        It 'Should handle single word commands' {
            $ast = New-MockCommandAst 'ssh'
            # For very short commands, the function may return the command itself
            { Get-PrevAst -commandAst $ast -cursorPosition 3 } | Should -Not -Throw
        }

        It 'Should return a string value' {
            $ast = New-MockCommandAst 'ssh -l user'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 11
            $result | Should -BeOfType [string]
        }

        It 'Should handle paths with slashes at end of command' {
            $ast = New-MockCommandAst 'ssh user@host:/path/to/file'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 100
            $result | Should -Be 'user@host:/path/to/file'
        }

        It 'Should handle arguments with dots' {
            $ast = New-MockCommandAst 'ssh server.example.com'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 100
            $result | Should -Be 'server.example.com'
        }
    }

    Context 'Real-world scenarios' {
        It 'Should work for GPG recipient completion' {
            # When user types: gpg --recipient <cursor>
            $ast = New-MockCommandAst 'gpg --recipient value'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 20
            # The function should help identify we're after --recipient
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should work for SSH cipher completion' {
            # When user types: ssh -c <cursor>
            $ast = New-MockCommandAst 'ssh -c aes'
            $result = Get-PrevAst -commandAst $ast -cursorPosition 10
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
