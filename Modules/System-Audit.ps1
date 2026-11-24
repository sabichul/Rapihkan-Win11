. "$PSScriptRoot\Common-Utilities.ps1"
function Invoke-SystemAudit {
 [CmdletBinding()]param([string[]]$Drive)
 $os=Get-CimInstance Win32_OperatingSystem; $cs=Get-CimInstance Win32_ComputerSystem; $cpu=Get-CimInstance Win32_Processor|Select-Object -First 1; $gpus=@(Get-CimInstance Win32_VideoController|ForEach-Object Name)
 $drives=Get-PSDrive -PSProvider FileSystem|Where-Object {$_.Root -match '^[A-Z]:\\$'}|ForEach-Object {[pscustomobject]@{Drive=$_.Name;TotalGB=[math]::Round(($_.Used+$_.Free)/1GB,2);UsedGB=[math]::Round($_.Used/1GB,2);FreeGB=[math]::Round($_.Free/1GB,2);FreePercent=[math]::Round(100*$_.Free/($_.Used+$_.Free),2)}}
 [pscustomobject]@{Timestamp=(Get-Date).ToString('o');Computer=$env:COMPUTERNAME;Windows="$($os.Caption) $($os.Version) build $($os.BuildNumber)";Architecture=$os.OSArchitecture;UptimeHours=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalHours,2);Administrator=Test-AdministratorPrivilege;Cpu=$cpu.Name;LogicalProcessors=$cpu.NumberOfLogicalProcessors;RamGB=[math]::Round($cs.TotalPhysicalMemory/1GB,2);Gpu=$gpus -join '; ';Drives=$drives}
}