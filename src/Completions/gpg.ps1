function Get-KeyCompletions {
    $o = gpg --list-keys --keyid-format LONG

    # uids
    $m = $o | Select-String -Pattern "^uid.*]\s(?<username>.*)\s<(?<email>.*@.*)>"
    $set = New-Object System.Collections.Generic.HashSet[String] # uids may repeat, we do not want this
    foreach ($i in $m) {
        $g = $i.Matches[0].Groups
        [void]$set.Add( $g["username"].Value)
        [void]$set.Add( $g["email"].Value)
    }
    $set | ForEach-Object {
        $_
    }
    # keyids
    $m = $o | Select-String -Pattern "^pub.*/(?<keyid>[0-9,A-Z]*) "
    foreach ($i in $m) {
        $i.Matches[0].Groups["keyid"].Value
    }
}

$gpgScriptBlock = {
    param($wordToComplete, $commandAst, $cursorPosition)

    $prev = Get-PrevAst $commandAst $cursorPosition

    switch ($prev) {
        ("--export" , "--sign-key" , "--lsign-key" , "--nrsign-key" , "--nrlsign-key" , "--edit-key", "--recipient", "-r" |
        Select-String -Pattern $prev -SimpleMatch -CaseSensitive ) {
            Get-KeyCompletions | Where-Object {
                $_ -like "$wordToComplete*"
            }
        }
    }

    if ($wordToComplete -like "-*" -or $prev -like "gpg*") {
        gpg --dump-options | Where-Object {
            $_ -like "$wordToComplete*"
        } | ForEach-Object {
            $_
        }
    }
}

$gpgvScriptBlock = {
    param($wordToComplete, $commandAst, $cursorPosition)

    if ($wordToComplete -like "-*") {
        "--verbose", "--quiet", "--keyring", "--output", "--ignore-time-conflict", "--status-fd", "--weak-digest" | 
        Where-Object {
            $_ -like "$wordToComplete*"
        } | ForEach-Object {
            $_
        }
    }
}

Register-ArgumentCompleter -CommandName gpg -Native -ScriptBlock $gpgScriptBlock
Register-ArgumentCompleter -CommandName gpgv -Native -ScriptBlock $gpgvScriptBlock