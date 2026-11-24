param([string]$ToolkitRoot=(Split-Path -Parent $PSScriptRoot))
. "$ToolkitRoot\Modules\Common-Utilities.ps1"
$sandbox=Join-Path $env:TEMP "W11Toolkit-Safety-$([guid]::NewGuid())";New-Item -ItemType Directory -Path $sandbox|Out-Null
try { $f=Join-Path $sandbox 'sample.txt';'safe test'|Set-Content $f;$item=Get-Item $f;$result=Test-SafeToMove $item (Join-Path $sandbox 'target.txt');if(!$result){throw 'Expected safe sandbox move validation.'};'PASSED: safe sandbox validation' } finally { Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue }
. "$ToolkitRoot\Modules\File-Organizer.ps1"
function Confirm-ThreeTimes { param([string]$Action,[string]$Summary) $true }
$sandbox=Join-Path $env:TEMP "RapihkanWin11-Organization-$([guid]::NewGuid())";New-Item -ItemType Directory -Path $sandbox|Out-Null
try { 'safe test'|Set-Content (Join-Path $sandbox 'sample.pdf');$result=Invoke-FileOrganization -Path $sandbox -Apply;if(!(Test-Path -LiteralPath (Join-Path $sandbox 'Documents\sample.pdf'))){throw 'Expected sandbox file to move into its configured Documents category.'};if($result.Moved.Count -ne 1){throw 'Expected exactly one sandbox file to move.'};'PASSED: reversible organization action' } finally { Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue }