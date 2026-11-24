. "$PSScriptRoot\Common-Utilities.ps1"
function Get-StorageAnalysis {
 [CmdletBinding()]param([string]$Path='C:\',[int]$Top=50,[int]$MinimumFileSizeMB=100)
 $root=Get-CanonicalPath $Path; $files=[Collections.Generic.List[object]]::new(); $folders=@{}; $count=0
 Get-ChildItem -LiteralPath $root -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object { if(Test-ReparsePoint $_ -or Test-CloudPlaceholder $_){return}; $count++; if($_.Length -ge $MinimumFileSizeMB*1MB){$files.Add([pscustomobject]@{Path=$_.FullName;SizeBytes=$_.Length;Size=(Format-ByteSize $_.Length);LastWrite=$_.LastWriteTime})}; $parent=$_.Directory.FullName; if(!$folders.ContainsKey($parent)){$folders[$parent]=[Int64]0};$folders[$parent]+=$_.Length }
 [pscustomobject]@{Path=$root;ScannedFiles=$count;LargeFiles=@($files|Sort-Object SizeBytes -Descending|Select-Object -First $Top);LargestFolders=@($folders.GetEnumerator()|ForEach-Object {[pscustomobject]@{Path=$_.Key;SizeBytes=$_.Value;Size=(Format-ByteSize $_.Value)}}|Sort-Object SizeBytes -Descending|Select-Object -First $Top)}
}