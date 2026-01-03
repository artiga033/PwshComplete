#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
    $script:ManifestPath = Join-Path $script:ModulePath 'PwshComplete.psd1'
    $script:ModuleFile = Join-Path $script:ModulePath 'PwshComplete.psm1'
}

Describe 'PwshComplete Module' {
    Context 'Module Manifest' {
        It 'Should have a valid manifest file' {
            Test-Path $script:ManifestPath | Should -BeTrue
        }

        It 'Should have a valid manifest' {
            { Test-ModuleManifest -Path $script:ManifestPath -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should have correct root module' {
            $manifest = Test-ModuleManifest -Path $script:ManifestPath
            $manifest.RootModule | Should -Be 'PwshComplete.psm1'
        }

        It 'Should have a valid GUID' {
            $manifest = Test-ModuleManifest -Path $script:ManifestPath
            $manifest.Guid | Should -Not -BeNullOrEmpty
            { [Guid]::Parse($manifest.Guid) } | Should -Not -Throw
        }

        It 'Should have a valid version' {
            $manifest = Test-ModuleManifest -Path $script:ManifestPath
            $manifest.Version | Should -Not -BeNullOrEmpty
        }

        It 'Should require PowerShell 5.0 or higher' {
            $manifest = Test-ModuleManifest -Path $script:ManifestPath
            $manifest.PowerShellVersion | Should -BeGreaterOrEqual '5.0'
        }
    }

    Context 'Module Structure' {
        It 'Should have a Utils.ps1 file' {
            Test-Path (Join-Path $script:ModulePath 'Utils.ps1') | Should -BeTrue
        }

        It 'Should have a Completions directory' {
            Test-Path (Join-Path $script:ModulePath 'Completions') | Should -BeTrue
        }

        It 'Should have completion scripts in Completions directory' {
            $completions = Get-ChildItem -Path (Join-Path $script:ModulePath 'Completions') -Filter '*.ps1'
            $completions.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Module Loading' {
        BeforeAll {
            # Remove module if loaded
            Get-Module PwshComplete -ErrorAction SilentlyContinue | Remove-Module -Force
        }

        AfterAll {
            Get-Module PwshComplete -ErrorAction SilentlyContinue | Remove-Module -Force
        }

        It 'Should load without errors' {
            { Import-Module $script:ManifestPath -Force -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should be loaded after import' {
            Import-Module $script:ManifestPath -Force
            Get-Module PwshComplete | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Module Entry Point (psm1)' {
        It 'Should exist' {
            Test-Path $script:ModuleFile | Should -BeTrue
        }

        It 'Should contain Get-ChildItem for loading completions' {
            $content = Get-Content $script:ModuleFile -Raw
            $content | Should -Match 'Get-ChildItem'
        }

        It 'Should use -CommandType Application for performance' {
            $content = Get-Content $script:ModuleFile -Raw
            $content | Should -Match '-CommandType Application'
        }

        It 'Should use -ErrorAction Ignore for performance' {
            $content = Get-Content $script:ModuleFile -Raw
            $content | Should -Match '-ErrorAction Ignore'
        }

        It 'Should dot-source Utils.ps1' {
            $content = Get-Content $script:ModuleFile -Raw
            $content | Should -Match '\.\s+\$PSScriptRoot/Utils\.ps1'
        }
    }
}

Describe 'Completion Scripts Validation' {
    BeforeAll {
        $script:CompletionsPath = Join-Path $script:ModulePath 'Completions'
        $script:CompletionFiles = Get-ChildItem -Path $script:CompletionsPath -Filter '*.ps1'
    }

    Context 'All completion scripts' {
        It 'Should have valid PowerShell syntax for <_>' -ForEach @(
            (Get-ChildItem -Path (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'src') 'Completions') -Filter '*.ps1').Name
        ) {
            $filePath = Join-Path $script:CompletionsPath $_
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($filePath, [ref]$null, [ref]$errors)
            $errors.Count | Should -Be 0 -Because "File $_ should have no syntax errors"
        }

        It 'Should contain Register-ArgumentCompleter for <_>' -ForEach @(
            (Get-ChildItem -Path (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'src') 'Completions') -Filter '*.ps1' |
                Where-Object { $_.Name -ne 'deno.ps1' }).Name  # deno.ps1 uses Invoke-Expression instead
        ) {
            $filePath = Join-Path $script:CompletionsPath $_
            $content = Get-Content $filePath -Raw
            $content | Should -Match 'Register-ArgumentCompleter'
        }

        It 'Should use delegation pattern for deno.ps1' {
            $filePath = Join-Path $script:CompletionsPath 'deno.ps1'
            $content = Get-Content $filePath -Raw
            # deno.ps1 uses Invoke-Expression to register the completer from deno itself
            $content | Should -Match 'Invoke-Expression'
            $content | Should -Match 'deno completions powershell'
        }
    }
}
