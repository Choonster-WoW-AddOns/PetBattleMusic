<#
.SYNOPSIS
    Packages the AddOn with the BigWigs Packager and copies it to the WoW game directories.
    
    Requires https://github.com/Choonster-WoW-AddOns/PublishAddon to be installed in ~\source\repos\PublishAddon.
#>

$ErrorActionPreference = 'Stop'

$global:WOW_HOME = 'D:\World of Warcraft'

[string] $AddOnDir = Join-Path $global:WOW_HOME '_retail_\Interface\AddOns\PetBattleMusic'
[string] $BackupDir = "$AddOnDir.backup"
[string[]] $PathsToBackup = @('Music', 'ogginfo', 'config.lua', 'music.lua')

Import-Module '~\source\repos\PublishAddon\wow.psm1'

function Copy-BackupItem {
    param (
        [Parameter(Mandatory)]
        [string]
        $RelativePath,
        [Parameter(Mandatory)]
        [string]
        $SourceDir,
        [Parameter(Mandatory)]
        [string]
        $DestinationDir,
        [Parameter(Mandatory)]
        [string]
        $Message
    )

    Write-Host $Message
    
    $sourcePath = Join-Path $SourceDir $RelativePath
    $destinationPath = Join-Path $DestinationDir $RelativePath

    $isDirectory = Test-Path -LiteralPath $sourcePath -PathType Container

    if ($isDirectory -and (Test-Path $destinationPath)) {
        Remove-Item -LiteralPath $destinationPath -Recurse -Force
    }

    Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse:$isDirectory
}

[bool]$ShouldBackup = Test-Path -LiteralPath $AddOnDir

if ($ShouldBackup) {
    if (-not (Test-Path -LiteralPath $BackupDir)) {
        New-Item -ItemType Directory -Path $BackupDir | Out-Null
    }

    $PathsToBackup | ForEach-Object {
        Copy-BackupItem `
            -RelativePath $_ `
            -SourceDir $AddOnDir `
            -DestinationDir $BackupDir `
            -Message "Backing up $_"
    }
}

Publish-Addon -Flavor Retail -SkipTocCreation

if ($ShouldBackup) {
    $PathsToBackup | ForEach-Object {
        Copy-BackupItem `
            -RelativePath $_ `
            -SourceDir $BackupDir `
            -DestinationDir $AddOnDir `
            -Message "Restoring $_"
    }
}
