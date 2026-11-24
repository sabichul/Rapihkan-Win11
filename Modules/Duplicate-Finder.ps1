. "$PSScriptRoot\Common-Utilities.ps1"
function Find-DuplicateFiles {
 [CmdletBinding()]param([string]$Path,[Int64]$MinimumFileSize=1MB)
 $root=Get-CanonicalPath $Path; $groups=Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue|Where-Object {$_.Length -ge $MinimumFileSize -and -not(Test-ReparsePoint $_) -and -not(Test-CloudPlaceholder $_)}|Group-Object Length|Where-Object Count -gt 1; $result=[Collections.Generic.List[object]]::new()
 foreach($g in $groups){$hashes=$g.Group|ForEach-Object {[pscustomobject]@{File=$_;Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}}|Group-Object Hash|Where-Object Count -gt 1; foreach($h in $hashes){$result.Add([pscustomobject]@{Hash=$h.Name;SizeBytes=$g.Name;Copies=$h.Count;PotentialSavings=[Int64]$g.Name*($h.Count-1);Paths=@($h.Group|ForEach-Object {$_.File.FullName});Risk='YELLOW';Action='Manual review only'})}}
 $result
}