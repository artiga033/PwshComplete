## pwsh-complete

Add **Tab** completions for popular cli tools on powershell.

## Installation
### Quick Start
``` powershell
Install-Module -Name PwshComplete
Import-Module PwshComplete
```
You may modify your powershell profile to make it load automatically:
``` powershell
notepad $PROFILE  
```
Note that if the file doesn't exist, you need to create it manually by checking the `$PROFILE` variable.


And add the following line to the end of the file:
``` powershell
Import-Module PwshComplete
```

## Works for:

- [x] adb
- [ ] cargo
- [ ] curl
- [x] deno
- [x] dotnet
- [x] gpg & gpgv
- [x] ssh & scp