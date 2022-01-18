#!pwsh
#Requires -Version 7

using namespace System.IO
using namespace System.IO.Compression

[CmdletBinding()]
param(
    [ValidateScript({ Test-Path -PathType Container $_ })]
    $GameUserDir = (Get-Item "$ENV:APPDATA\Godot\app_userdata\Cruelty Squad\"),
    [ValidateScript({ Test-Path -PathType Container $_ })]
    $ModSourceDir = $PSScriptRoot
)

$Local:ErrorActionPreference = ([System.Management.Automation.ActionPreference]::Stop)

$zipTempDir = "crus-modbase-zip"
$zipTempPath = [Path]::Join([Path]::GetTempPath(), $zipTempDir)
if(Test-Path $zipTempPath)
{
    Remove-Item -Force -Recurse $zipTempPath
}
mkdir $zipTempPath
$zipDir = Get-Item $zipTempPath

$excluded = @(
    "build.ps1"
    ".git"
    ".gitignore"
    "mod.json"
)

Copy-Item -Force -Recurse -Exclude $excluded $ModSourceDir\* $zipDir

# -> mod.zip
$zipOutPath = [Path]::Join($GameUserDir, 'mods/CruS Mod Base/mod.zip')
if(Test-Path $zipOutPath)
{
    Remove-Item $zipOutPath
}
# Temp duct tape: emove all base game gd files that are now compiled as well
Get-ChildItem $zipDir -Exclude MOD_CONTENT `
  | ForEach-Object {
    if($_  -is [FileInfo])
    {
        if($_.Extension -match '.gd$' -and (test-path "$($_.FullName)c"))
        {
            Write-Host -F Magenta "Removing $_"
            Remove-Item $_
        }
    }
    else
    {
        Get-ChildItem -Filter *.gd -recurse $_ `
            | ForEach-Object {
                if($_.Extension -match '.gd$' -and (test-path "$($_.FullName)c"))
                {
                    Write-Host -F Magenta "Removing $_"
                    Remove-Item $_
                }
            }
    }
}
[ZipFile]::CreateFromDirectory($zipDir, $zipOutPath)
if(-not (Test-Path $zipOutPath))
{
    Write-Warning "Created zip expected but not found: $zipOutPath"
}

# -> mod.json
Copy-Item $ModSourceDir/mod.json ([Path]::Join($GameUserDir, 'mods/CruS Mod Base/mod.json'))