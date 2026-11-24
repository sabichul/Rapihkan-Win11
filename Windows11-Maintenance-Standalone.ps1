<#
.SYNOPSIS
  Peluncur Rapihkan Win11.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [ValidateSet('Interactive','Audit','StorageAnalysis','JunkScan','SafeCleanup','ApplySafeCleanup','DeepCleanup','BrowserScan','DeveloperScan','DuplicateScan','Organize','ApplyOrganize','Startup','Performance','StorageOptimize','HealthCheck','FullMaintenance')]
    [string]$Mode = 'Interactive',
    [string[]]$Drive,
    [string]$Path,
    [switch]$ExportReport,
    [switch]$NonInteractive
)

$parameters = @{ Mode = $Mode }
if ($Drive) { $parameters.Drive = $Drive }
if ($Path) { $parameters.Path = $Path }
if ($ExportReport) { $parameters.ExportReport = $true }
if ($NonInteractive) { $parameters.NonInteractive = $true }
& (Join-Path $PSScriptRoot 'Windows11-Maintenance.ps1') @parameters