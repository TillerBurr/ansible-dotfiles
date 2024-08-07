# Install-Module -Name Terminal-Icons -Repository PSGallery
# Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force -SkipPublisherCheck
# winget install JanDeDobbeleer.OhMyPosh

Import-Module PSReadLine
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

Set-PSReadlineKeyHandler -Key Tab -Function Complete
try { $null = gcm pshazz -ea stop; pshazz init 'default' } catch { }
Import-Module -Name Terminal-Icons
oh-my-posh init pwsh --config $env:POSH_THEMES_PATH/powerlevel10k_rainbow.omp.json | Invoke-Expression