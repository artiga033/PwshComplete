$scriptBlock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $c = $commandAst.ToString()
    $cmds = @("backup", "get-state", "push", "start-server", "bugreport", "help", "reboot", "status-window", "connect", "install", "reboot-bootloader", "sync", "devices", "jdwp", "remount", "uninstall", "disconnect", "kill-server", "restore", "version", "emu", "logcat", "root", "wait-for-device", "forward", "ppp", "shell", "get-serialno", "pull", "sideload")
    
    $success = $c -cmatch "\s([a-z,-]+)\s?"
    if ($success -and $Matches.1 -in $cmds) {
        $cmd = $Matches.1
        switch ($cmd) {
            "reboot" { 
                "bootloader", "recovery"
            }
            Default {}
        }
    }
    else {
        $cmds | Where-Object {
            $_ -like "$wordToComplete*"
        }
    }
}

Register-ArgumentCompleter -CommandName adb -Native -ScriptBlock $scriptBlock
