# PwshComplete

## Project Overview

PwshComplete is a PowerShell module that provides tab completion for various CLI tools. It's published to the PowerShell Gallery as `PwshComplete`.

## Architecture

- **PwshComplete.psm1**: Entry point that loads Utils.ps1 and dynamically sources completion scripts from `Completions/` only for commands that exist on the system
- **PwshComplete.psd1**: Module manifest (version, metadata, exports)
- **Utils.ps1**: Shared utilities (e.g., `Get-PrevAst` for parsing command AST)
- **Completions/*.ps1**: Individual completion scripts, one per tool. Each script:
  - Defines a script block accepting `($wordToComplete, $commandAst, $cursorPosition)`
  - Registers the completer via `Register-ArgumentCompleter -CommandName <tool> -Native -ScriptBlock $scriptBlock`

## Adding a New Completion

1. Create `Completions/<toolname>.ps1`
2. Define completion logic using `Register-ArgumentCompleter -CommandName <toolname> -Native -ScriptBlock { ... }`
3. The module auto-loads it if the command exists on the system

## Testing Completions

```powershell
Import-Module .\PwshComplete.psd1 -Force
# Then type the command and press Tab to test
```
