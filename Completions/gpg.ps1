$scriptBlock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    
    $c = $commandAst.ToString()
    $prev = $commandAst.CommandElements[-1].ToString()
    if ($cursorPosition -le $c.Length) {
        $r = $c.LastIndexOf(" ", $cursorPosition)
        $l = $c.LastIndexOf(" ", $r - 1)
        while ($c[$r - 1] -eq ' ') {
            $r = $r - 1
        }
        $prev = $c.Substring($l + 1, $r - $l - 1)
    }

    switch ($prev) {
        ("--export" , "--sign-key" , "--lsign-key" , "--nrsign-key" , "--nrlsign-key" , "--edit-key", "--recipient", "-r" |
        Select-String -Pattern $prev -SimpleMatch -CaseSensitive ) {
            Get-KeyCompletions | Where-Object {
                $_ -like "$wordToComplete*"
            }
        }
    }

    if ($wordToComplete -like "-*") {
        gpg --dump-options | Where-Object {
            $_ -like "$wordToComplete*"
        } | ForEach-Object {
            $_
        }
    }
}

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

Register-ArgumentCompleter -CommandName gpg -Native -ScriptBlock $scriptBlock