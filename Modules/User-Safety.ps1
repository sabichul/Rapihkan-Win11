. "$PSScriptRoot\Common-Utilities.ps1"

function Confirm-ThreeTimes {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Action,[Parameter(Mandatory)][string]$Summary)
    $warnings = @(
        "Warning 1 of 3: $Action. $Summary This action can change a file location.",
        "Warning 2 of 3: Files are not permanently deleted, but you still need to make sure this recommendation is correct.",
        "Warning 3 of 3: Continue only if you understand that the change will happen now and be recorded in a report."
    )
    foreach ($warning in $warnings) {
        Write-Host "`n$warning" -ForegroundColor Yellow
        if ((Read-Host "Type YES to continue") -cne 'YES') {
            Write-Host 'Action cancelled. No files were changed.' -ForegroundColor Cyan
            return $false
        }
    }
    $true
}

function Write-UserProgress {
    param([string]$Activity,[int]$Current,[int]$Total,[string]$Status)
    $percent = if ($Total -gt 0) { [math]::Min(100, [math]::Round(($Current / $Total) * 100)) } else { 100 }
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $percent
}