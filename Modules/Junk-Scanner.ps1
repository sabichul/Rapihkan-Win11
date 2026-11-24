. "$PSScriptRoot\Common-Utilities.ps1"
function Find-JunkCandidates {
 [CmdletBinding()]param([int]$MinimumAgeDays=7)
 $cut=(Get-Date).AddDays(-$MinimumAgeDays); $paths=@($env:TEMP,(Join-Path $env:WINDIR 'Temp'))|Where-Object {Test-Path -LiteralPath $_}; $out=[Collections.Generic.List[object]]::new()
 foreach($p in $paths){Get-ChildItem -LiteralPath $p -File -Recurse -Force -ErrorAction SilentlyContinue|Where-Object {$_.LastWriteTime -lt $cut -and -not (Test-ReparsePoint $_) -and -not (Test-CloudPlaceholder $_)}|ForEach-Object {$out.Add([pscustomobject]@{Path=$_.FullName;Category='Temporary files';SizeBytes=$_.Length;Risk='GREEN';Action='Quarantine then review';Reason="Older than $MinimumAgeDays days"})}}
 $out
}