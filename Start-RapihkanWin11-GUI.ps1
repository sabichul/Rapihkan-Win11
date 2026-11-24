<#
.SYNOPSIS
  Starts the portable Rapihkan Win11 desktop window.
.DESCRIPTION
  No installation, shortcut, or system-wide change is required.
#>
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
Get-ChildItem -LiteralPath (Join-Path $root 'Modules') -Filter '*.ps1' -File|ForEach-Object {. $_.FullName}
Initialize-ToolkitFolders
Start-RapihkanGui