Set-StrictMode -Version Latest
$script:RapihkanWin11Root = Split-Path -Parent $PSScriptRoot

function Get-ToolkitRoot { $script:RapihkanWin11Root }
function Get-ToolkitPaths {
    $root = Get-ToolkitRoot
    [pscustomobject]@{ Root=$root; Config=(Join-Path $root 'Config'); Reports=(Join-Path $root 'Reports'); Logs=(Join-Path $root 'Logs'); Backup=(Join-Path $root 'Backup'); Quarantine=(Join-Path $root 'Quarantine') }
}
function Initialize-ToolkitFolders { (Get-ToolkitPaths).psobject.Properties.Value | ForEach-Object { if ($_ -ne (Get-ToolkitPaths).Root) { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }; @('Audit','Cleanup','Performance','Organization') | ForEach-Object { New-Item -ItemType Directory -Path (Join-Path (Get-ToolkitPaths).Reports $_) -Force | Out-Null } }
function Get-ToolkitSettings { param([string]$ConfigPath=(Join-Path (Get-ToolkitPaths).Config 'Settings.json')); if (!(Test-Path -LiteralPath $ConfigPath)) { throw "Configuration not found: $ConfigPath" }; Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json }
function Get-NowStamp { Get-Date -Format 'yyyyMMdd-HHmmss' }
function Format-ByteSize { param([Int64]$Bytes); if($Bytes -ge 1TB){'{0:N2} TB' -f ($Bytes/1TB)}elseif($Bytes -ge 1GB){'{0:N2} GB' -f ($Bytes/1GB)}elseif($Bytes -ge 1MB){'{0:N2} MB' -f ($Bytes/1MB)}elseif($Bytes -ge 1KB){'{0:N2} KB' -f ($Bytes/1KB)}else{"$Bytes B"} }
function Test-AdministratorPrivilege { $i=[Security.Principal.WindowsIdentity]::GetCurrent(); ([Security.Principal.WindowsPrincipal]::new($i)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Get-CanonicalPath { param([string]$Path); (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path.TrimEnd('\') }
function Test-ReparsePoint { param([System.IO.FileSystemInfo]$Item); [bool]($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) }
function Test-CloudPlaceholder { param([System.IO.FileInfo]$File); [bool]($File.Attributes.ToString() -match 'Offline') }
function Test-ProtectedPath { param([string]$Path); $p=$Path.ToLowerInvariant(); [bool](@('c:\windows','c:\program files','c:\program files (x86)','c:\programdata','c:\recovery','c:\boot','c:\system volume information') | Where-Object {$p -eq $_ -or $p.StartsWith("$_\")} | Select-Object -First 1) }
function Test-FileLock { param([System.IO.FileInfo]$File); try { $s=[IO.File]::Open($File.FullName,'Open','ReadWrite','None'); $s.Dispose(); $false } catch { $true } }
function Test-SafeToMove { param([System.IO.FileInfo]$File,[string]$Destination); if(Test-ProtectedPath $File.FullName){return $false}; if(Test-ReparsePoint $File){return $false}; if(Test-CloudPlaceholder $File){return $false}; if(Test-FileLock $File){return $false}; if(Test-Path -LiteralPath $Destination){return $false}; $true }
function Test-SafeToDelete { param([System.IO.FileInfo]$File); $false }
function Write-ToolkitLog { param([string]$Level,[string]$Message,[string]$Module='Core'); Initialize-ToolkitFolders; $line="$(Get-Date -Format o) [$Level] [$Module] $Message"; Add-Content -LiteralPath (Join-Path (Get-ToolkitPaths).Logs "Maintenance_$(Get-Date -Format 'yyyy-MM-dd').log") -Value $line -Encoding utf8; $line }
function New-OperationManifest { param([object[]]$Items,[string]$Type,[string]$Folder='Cleanup'); Initialize-ToolkitFolders; $id="OP-$(Get-NowStamp)-$([guid]::NewGuid().ToString('N').Substring(0,8))"; $file=Join-Path (Join-Path (Get-ToolkitPaths).Reports $Folder) "$id.json"; [pscustomobject]@{OperationId=$id;Created=(Get-Date).ToString('o');Type=$Type;ApprovalRequired=$true;Items=@($Items)} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $file -Encoding utf8; $file }
function Export-ToolkitData { param([object]$Data,[string]$BaseName,[string]$Folder='Audit'); Initialize-ToolkitFolders; $dir=Join-Path (Get-ToolkitPaths).Reports $Folder; $json=Join-Path $dir "$BaseName.json"; $csv=Join-Path $dir "$BaseName.csv"; $md=Join-Path $dir "$BaseName.md"; $Data|ConvertTo-Json -Depth 8|Set-Content $json -Encoding utf8; @($Data)|Export-Csv $csv -NoTypeInformation -Encoding utf8; "# $BaseName`n`nGenerated: $(Get-Date -Format o)`n`n````json`n$($Data|ConvertTo-Json -Depth 5)`n````"|Set-Content $md -Encoding utf8; [pscustomobject]@{Json=$json;Csv=$csv;Markdown=$md} }