. "$PSScriptRoot\Common-Utilities.ps1"
function Move-FileToQuarantine {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]param([Parameter(Mandatory)][string]$Path,[string]$Reason='Manual review')
 $file=Get-Item -LiteralPath $Path -ErrorAction Stop
 $dir=Join-Path (Get-ToolkitPaths).Quarantine ("Q-$(Get-NowStamp)-$([guid]::NewGuid().ToString('N').Substring(0,8))")
 $dest=Join-Path $dir $file.Name
 if($file.PSIsContainer -or -not(Test-SafeToMove $file $dest)){throw 'Safety validation failed; no file was moved.'}
 if($PSCmdlet.ShouldProcess($file.FullName,"Quarantine to $dest")){New-Item -ItemType Directory -Path $dir -Force|Out-Null;Move-Item -LiteralPath $file.FullName -Destination $dest;[pscustomobject]@{OriginalPath=$file.FullName;QuarantinePath=$dest;Reason=$Reason;Timestamp=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $dir 'manifest.json') -Encoding utf8;$dest}
}
function Restore-QuarantinedFile { [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]param([Parameter(Mandatory)][string]$ManifestPath);$m=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json;if(Test-Path -LiteralPath $m.OriginalPath){throw 'Original path exists; restore refused.'};if($PSCmdlet.ShouldProcess($m.QuarantinePath,"Restore to $($m.OriginalPath)")){New-Item -ItemType Directory -Path (Split-Path $m.OriginalPath -Parent) -Force|Out-Null;Move-Item -LiteralPath $m.QuarantinePath -Destination $m.OriginalPath} }