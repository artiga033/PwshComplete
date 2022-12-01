$commands = @("alias", "bucket", "cache", "cat", "checkup", "cleanup", "config", "create", "depends", "download", "export", "help", "hold", "home", "import", "info", "install", "list", "prefix", "reset", "search", "shim", "status", "unhold", "uninstall", "update", "virustotal", "which")

function SubCommandComples {
    param (
        [string]$subcommand
    )
    switch ($subcommand) {
        "alias" {
            @("add", "list", "rm")
        }
        "bucket" {
            @("add", "list", "known", "rm")
        }
        "cache" {
            @("show", "rm")
        }
        "cat" {

        }
        "checkup" {}
        "cleanup" {}
        "config" {}
        "create" {}
        "depends" {}
        "download" {}
        "export" {}
        "help" { $commands }
        "hold" {}
        "home" {}
        "import" {}
        "info" {}
        "install" {}
        "list" {}
        "prefix" {}
        "reset" {}
        "search" {}
        "shim" { @("add", "rm", "list", "info", "alter") }
        "status" {}
        "unhold" {}
        "uninstall" {}
        "update" {}
        "virustotal" {}
        "which" {}
        Default {}
    }
}
$scriptBlock = {
    param($wordToComplete, $commandAst, $cursorPosition)    
    $prev = Get-PrevAst $commandAst $cursorPosition

    $candi = @()
    if ($prev -in $commands) {
        $candi = SubCommandComples $prev
    }
    else {
        $candi = $commands
    }
    $candi | Where-Object { $_ -like "$wordToComplete*" }
}

Register-ArgumentCompleter -CommandName scoop -Native -ScriptBlock $scriptBlock
