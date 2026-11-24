<#
.SYNOPSIS
  Peluncur Rapihkan Win11.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Interactive','Gui','Audit','StorageAnalysis','JunkScan','SafeCleanup','ApplySafeCleanup','DeepCleanup','BrowserScan','DeveloperScan','CacheReview','DuplicateScan','Organize','ApplyOrganize','ApplySelectedOrganize','Startup','Performance','StorageOptimize','HealthCheck','FullMaintenance','History','Quarantine','RestoreQuarantine','AddExclusion','RemoveExclusion','AddCategory','ScheduleAudit','RemoveSchedule')]
    [string]$Mode = 'Interactive',
    [string[]]$Drive,
    [string]$Path,
    [string[]]$Source,
    [string]$ManifestPath,
    [string]$CategoryName,
    [string[]]$Extension,
    [string]$ScheduleTime = '09:00',
    [switch]$ExportReport,
    [switch]$NonInteractive
)

$parameters = @{ Mode = $Mode }
if ($Drive) { $parameters.Drive = $Drive }
if ($Path) { $parameters.Path = $Path }
if ($Source) { $parameters.Source = $Source }
if ($ManifestPath) { $parameters.ManifestPath = $ManifestPath }
if ($CategoryName) { $parameters.CategoryName = $CategoryName }
if ($Extension) { $parameters.Extension = $Extension }
if ($ScheduleTime -ne '09:00') { $parameters.ScheduleTime = $ScheduleTime }
if ($ExportReport) { $parameters.ExportReport = $true }
if ($NonInteractive) { $parameters.NonInteractive = $true }
& (Join-Path $PSScriptRoot 'Windows11-Maintenance.ps1') @parameters