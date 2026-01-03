#Requires -Modules Pester

BeforeAll {
    # Navigate from tests/Completions to project root, then to src
    $script:ProjectRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:ModulePath = Join-Path $script:ProjectRoot 'src'
    $script:CompletionScript = Join-Path $script:ModulePath 'Completions' 'adb.ps1'

    # Source the completion script to get the scriptBlock variable
    . $script:CompletionScript

    # The script block is stored in $scriptBlock variable
    $script:AdbCompleter = $scriptBlock

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

    function Invoke-AdbCompleter {
        param(
            [string]$CommandLine,
            [string]$WordToComplete = '',
            [int]$CursorPosition = -1
        )

        if ($CursorPosition -eq -1) {
            $CursorPosition = $CommandLine.Length
        }

        $ast = New-MockCommandAst -CommandLine $CommandLine
        & $script:AdbCompleter $WordToComplete $ast $CursorPosition
    }
}

Describe 'ADB Completion' {
    Context 'Command completion' {
        It 'Should complete all commands when no input given' {
            $result = Invoke-AdbCompleter -CommandLine 'adb ' -WordToComplete ''
            $result | Should -Contain 'devices'
            $result | Should -Contain 'shell'
            $result | Should -Contain 'install'
            $result | Should -Contain 'push'
            $result | Should -Contain 'pull'
        }

        It 'Should complete commands starting with "de"' {
            $result = Invoke-AdbCompleter -CommandLine 'adb de' -WordToComplete 'de'
            $result | Should -Contain 'devices'
            $result | Should -Not -Contain 'shell'
        }

        It 'Should complete commands starting with "sh"' {
            $result = Invoke-AdbCompleter -CommandLine 'adb sh' -WordToComplete 'sh'
            $result | Should -Contain 'shell'
            $result | Should -Not -Contain 'devices'
        }

        It 'Should complete commands starting with "re"' {
            $result = Invoke-AdbCompleter -CommandLine 'adb re' -WordToComplete 're'
            $result | Should -Contain 'reboot'
            $result | Should -Contain 'reboot-bootloader'
            $result | Should -Contain 'remount'
            $result | Should -Contain 'restore'
        }

        It 'Should complete commands starting with "s"' {
            $result = Invoke-AdbCompleter -CommandLine 'adb s' -WordToComplete 's'
            $result | Should -Contain 'shell'
            $result | Should -Contain 'start-server'
            $result | Should -Contain 'status-window'
            $result | Should -Contain 'sync'
            $result | Should -Contain 'sideload'
        }

        It 'Should complete commands starting with "install"' {
            $result = Invoke-AdbCompleter -CommandLine 'adb inst' -WordToComplete 'inst'
            $result | Should -Contain 'install'
        }

        It 'Should return empty for non-matching prefix' {
            $result = Invoke-AdbCompleter -CommandLine 'adb xyz' -WordToComplete 'xyz'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Subcommand completion' {
        It 'Should complete reboot subcommands with bootloader' {
            $result = Invoke-AdbCompleter -CommandLine 'adb reboot ' -WordToComplete ''
            $result | Should -Contain 'bootloader'
            $result | Should -Contain 'recovery'
        }

        It 'Should complete reboot with "boot" filter' {
            $result = Invoke-AdbCompleter -CommandLine 'adb reboot boot' -WordToComplete 'boot'
            # After matching reboot command, should return subcommands
            # but current implementation just returns bootloader, recovery
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should not complete subcommands for shell command' {
            $result = Invoke-AdbCompleter -CommandLine 'adb shell ' -WordToComplete ''
            # Shell doesn't have predefined subcommands in this implementation
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'All known commands' {
        BeforeAll {
            $script:AllAdbCommands = @(
                'backup', 'get-state', 'push', 'start-server', 'bugreport', 'help',
                'reboot', 'status-window', 'connect', 'install', 'reboot-bootloader',
                'sync', 'devices', 'jdwp', 'remount', 'uninstall', 'disconnect',
                'kill-server', 'restore', 'version', 'emu', 'logcat', 'root',
                'wait-for-device', 'forward', 'ppp', 'shell', 'get-serialno', 'pull', 'sideload'
            )
        }

        It 'Should include <_> in completions' -ForEach @(
            'backup', 'devices', 'shell', 'install', 'uninstall',
            'push', 'pull', 'logcat', 'reboot', 'connect', 'disconnect'
        ) {
            $result = Invoke-AdbCompleter -CommandLine 'adb ' -WordToComplete ''
            $result | Should -Contain $_
        }

        It 'Should have exactly 30 base commands available' {
            $result = Invoke-AdbCompleter -CommandLine 'adb ' -WordToComplete ''
            $result.Count | Should -Be 30
        }
    }

    Context 'Edge cases' {
        It 'Should handle empty word to complete' {
            $result = Invoke-AdbCompleter -CommandLine 'adb ' -WordToComplete ''
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Should be case-sensitive for command matching' {
            # The regex uses -cmatch which is case-sensitive
            $result = Invoke-AdbCompleter -CommandLine 'adb DEVICES' -WordToComplete 'DEVICES'
            # Since commands are lowercase, uppercase should not match existing command
            $result | Should -BeNullOrEmpty
        }

        It 'Should handle partial command "d"' {
            $result = Invoke-AdbCompleter -CommandLine 'adb d' -WordToComplete 'd'
            $result | Should -Contain 'devices'
            $result | Should -Contain 'disconnect'
        }

        It 'Should handle hyphenated commands' {
            $result = Invoke-AdbCompleter -CommandLine 'adb kill' -WordToComplete 'kill'
            $result | Should -Contain 'kill-server'
        }

        It 'Should complete wait-for-device' {
            $result = Invoke-AdbCompleter -CommandLine 'adb wait' -WordToComplete 'wait'
            $result | Should -Contain 'wait-for-device'
        }

        It 'Should handle get- prefix commands' {
            $result = Invoke-AdbCompleter -CommandLine 'adb get-' -WordToComplete 'get-'
            $result | Should -Contain 'get-state'
            $result | Should -Contain 'get-serialno'
        }
    }

    Context 'Regex matching edge cases' {
        It 'Should handle quoted strings in command' {
            # Testing the regex behavior - command matching uses \s
            # This test just ensures no crash
            { Invoke-AdbCompleter -CommandLine 'adb "shell" ' -WordToComplete '' } | Should -Not -Throw
        }

        It 'Should handle multiple spaces before command' {
            $result = Invoke-AdbCompleter -CommandLine 'adb  devices ' -WordToComplete ''
            # After a recognized command, returns empty or subcommands
            $result | Should -BeNullOrEmpty
        }
    }
}
