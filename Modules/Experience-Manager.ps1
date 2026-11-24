. "$PSScriptRoot\Common-Utilities.ps1"
. "$PSScriptRoot\User-Safety.ps1"
. "$PSScriptRoot\Quarantine-Manager.ps1"

function Get-RapihkanHistoryPath { Join-Path (Get-ToolkitPaths).Logs 'Action-History.jsonl' }
function Add-RapihkanHistory {
    param([string]$Type,[string]$Status,[string]$Summary,[object]$Details)
    $record=[pscustomobject]@{Timestamp=(Get-Date).ToString('o');Type=$Type;Status=$Status;Summary=$Summary;Details=$Details}
    $record|ConvertTo-Json -Depth 5 -Compress|Add-Content -LiteralPath (Get-RapihkanHistoryPath) -Encoding utf8
    $record
}
function Get-RapihkanHistory {
    param([int]$Last=50)
    $path=Get-RapihkanHistoryPath
    if(!(Test-Path -LiteralPath $path)){return @()}
    @(Get-Content -LiteralPath $path|Where-Object {$_}|ForEach-Object {$_|ConvertFrom-Json}|Select-Object -Last $Last)
}
function Get-QuarantineItems {
    $root=(Get-ToolkitPaths).Quarantine
    if(!(Test-Path -LiteralPath $root)){return @()}
    @(Get-ChildItem -LiteralPath $root -Filter manifest.json -Recurse -File -ErrorAction SilentlyContinue|ForEach-Object {try{$m=Get-Content -LiteralPath $_.FullName -Raw|ConvertFrom-Json;$m|Add-Member NoteProperty ManifestPath $_.FullName -Force;$m|Add-Member NoteProperty Exists (Test-Path -LiteralPath $m.QuarantinePath) -Force;$m}catch{}})
}
function Restore-RapihkanQuarantineItem {
    [CmdletBinding(SupportsShouldProcess=$true)]param([Parameter(Mandatory)][string]$ManifestPath)
    $item=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
    if(!(Confirm-ThreeTimes -Action 'Restoring a quarantined file' -Summary "The file will return to $($item.OriginalPath).")){return [pscustomobject]@{Status='Cancelled';ManifestPath=$ManifestPath}}
    Restore-QuarantinedFile -ManifestPath $ManifestPath -Confirm:$false
    Add-RapihkanHistory 'QuarantineRestore' 'Complete' "Restored $($item.QuarantinePath)" $item|Out-Null
    [pscustomobject]@{Status='Complete';RestoredTo=$item.OriginalPath}
}
function Get-CacheReview {
    $targets=@(
        @{App='Google Chrome';Path="$env:LOCALAPPDATA\Google\Chrome\User Data";Kind='Browser profile';Risk='YELLOW'},
        @{App='Microsoft Edge';Path="$env:LOCALAPPDATA\Microsoft\Edge\User Data";Kind='Browser profile';Risk='YELLOW'},
        @{App='Firefox';Path="$env:APPDATA\Mozilla\Firefox\Profiles";Kind='Browser profile';Risk='YELLOW'},
        @{App='Visual Studio Code';Path="$env:APPDATA\Code\Cache";Kind='Application cache';Risk='GREEN'},
        @{App='npm';Path="$env:APPDATA\npm-cache";Kind='Developer cache';Risk='YELLOW'},
        @{App='pip';Path="$env:LOCALAPPDATA\pip\Cache";Kind='Developer cache';Risk='GREEN'},
        @{App='NuGet';Path="$env:USERPROFILE\.nuget\packages";Kind='Package cache';Risk='YELLOW'}
    )
    @($targets|Where-Object {Test-Path -LiteralPath $_.Path}|ForEach-Object {$size=(Get-ChildItem -LiteralPath $_.Path -File -Recurse -Force -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum;[pscustomobject]@{Application=$_.App;Path=$_.Path;Type=$_.Kind;SizeBytes=[int64]$size;Size=Format-ByteSize ([int64]$size);Risk=$_.Risk;Action='Review only; clear in the app when possible'}})
}
function Get-UserExclusions { $path=Join-Path (Get-ToolkitPaths).Config 'User-Exclusions.json';if(!(Test-Path -LiteralPath $path)){'{"Paths":[]}'|Set-Content -LiteralPath $path -Encoding utf8};(Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).Paths }
function Add-UserExclusion { param([Parameter(Mandatory)][string]$Path);$canonical=Get-CanonicalPath $Path;$file=Join-Path (Get-ToolkitPaths).Config 'User-Exclusions.json';$items=@(Get-UserExclusions)+$canonical;[pscustomobject]@{Paths=@($items|Sort-Object -Unique)}|ConvertTo-Json|Set-Content -LiteralPath $file -Encoding utf8;Get-UserExclusions }
function Remove-UserExclusion { param([Parameter(Mandatory)][string]$Path);$file=Join-Path (Get-ToolkitPaths).Config 'User-Exclusions.json';[pscustomobject]@{Paths=@(Get-UserExclusions|Where-Object {$_ -ne $Path})}|ConvertTo-Json|Set-Content -LiteralPath $file -Encoding utf8;Get-UserExclusions }
function Test-UserExcludedPath { param([string]$Path);$p=$Path.TrimEnd('\');[bool](Get-UserExclusions|Where-Object {$p -eq $_ -or $p.StartsWith("$_\")}|Select-Object -First 1) }
function Add-OrganizationCategory { param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][string[]]$Extensions);if($Name -notmatch '^[A-Za-z0-9 _-]+$'){throw 'Category name contains unsupported characters.'};$file=Join-Path (Get-ToolkitPaths).Config 'Organization-Rules.json';$rules=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json;if($rules.psobject.Properties.Name -contains $Name){throw 'That category already exists.'};$rules|Add-Member NoteProperty $Name @($Extensions|ForEach-Object {if($_.StartsWith('.')){$_}else{".$_"}}|Sort-Object -Unique);$rules|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $file -Encoding utf8;$rules }
function Register-RapihkanAuditSchedule {
    [CmdletBinding(SupportsShouldProcess=$true)]param([ValidateRange(1,31)][int]$Day=1,[ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')][string]$Time='09:00')
    $task='RapihkanWin11-WeeklyAudit';$script=Join-Path (Get-ToolkitPaths).Root 'Windows11-Maintenance.ps1';$command="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script`" -Mode Audit -NonInteractive -ExportReport"
    if($PSCmdlet.ShouldProcess($task,'Create or replace an audit-only weekly scheduled task')){& schtasks.exe /Create /TN $task /TR $command /SC WEEKLY /D MON /ST $Time /F|Out-Null;Add-RapihkanHistory 'Schedule' 'Complete' "Weekly audit scheduled for Monday $Time" $null|Out-Null;[pscustomobject]@{TaskName=$task;Schedule="Every Monday at $Time";Mode='Audit only'}}
}
function Unregister-RapihkanAuditSchedule {[CmdletBinding(SupportsShouldProcess=$true)]param();if($PSCmdlet.ShouldProcess('RapihkanWin11-WeeklyAudit','Delete scheduled audit task')){& schtasks.exe /Delete /TN RapihkanWin11-WeeklyAudit /F|Out-Null}}
function Show-RapihkanNotification { param([string]$Title='Rapihkan Win11',[string]$Message='The check has completed.');try{Add-Type -AssemblyName System.Windows.Forms;$n=New-Object Windows.Forms.NotifyIcon;$n.Icon=[Drawing.SystemIcons]::Information;$n.Visible=$true;$n.ShowBalloonTip(5000,$Title,$Message,[Windows.Forms.ToolTipIcon]::Info);Start-Sleep -Milliseconds 750;$n.Dispose()}catch{Write-ToolkitLog INFO "${Title}: $Message" 'Notification'|Out-Null} }
function Start-RapihkanGui {
    Add-Type -AssemblyName System.Windows.Forms;Add-Type -AssemblyName System.Drawing
    $form=[Windows.Forms.Form]::new();$form.Text='Rapihkan Win11';$form.Size=[Drawing.Size]::new(760,520);$form.StartPosition='CenterScreen';$form.BackColor=[Drawing.Color]::FromArgb(8,32,55)
    $title=[Windows.Forms.Label]::new();$title.Text='Rapihkan Win11';$title.ForeColor=[Drawing.Color]::White;$title.Font=[Drawing.Font]::new('Segoe UI',20,[Drawing.FontStyle]::Bold);$title.Location=[Drawing.Point]::new(24,18);$title.AutoSize=$true;$form.Controls.Add($title)
    $info=[Windows.Forms.Label]::new();$info.Text='Run a read-only check, then review results in this window.';$info.ForeColor=[Drawing.Color]::LightBlue;$info.Location=[Drawing.Point]::new(27,58);$info.AutoSize=$true;$form.Controls.Add($info)
    $output=[Windows.Forms.TextBox]::new();$output.Multiline=$true;$output.ScrollBars='Vertical';$output.ReadOnly=$true;$output.Font=[Drawing.Font]::new('Consolas',9);$output.Location=[Drawing.Point]::new(24,160);$output.Size=[Drawing.Size]::new(700,300);$form.Controls.Add($output)
    $actions=@(@('System audit',{Invoke-SystemAudit}),@('Performance',{Get-PerformanceBaseline}),@('Windows health',{Get-SystemHealthCheck}),@('Cache review',{Get-CacheReview}),@('History',{Get-RapihkanHistory}))
    $x=24;foreach($action in $actions){$button=[Windows.Forms.Button]::new();$button.Text=$action[0];$button.Location=[Drawing.Point]::new($x,100);$button.Size=[Drawing.Size]::new(126,38);$work=$action[1];$button.Add_Click({try{$output.Text=(& $work|Format-List *|Out-String);Show-RapihkanNotification -Message 'Check complete.'}catch{$output.Text=$_.Exception.Message}});$form.Controls.Add($button);$x+=140}
    [void]$form.ShowDialog()
}

function Invoke-SelectedOrganizationPlan {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string[]]$Source)
    $plan=@(Get-OrganizationPlan -Path $Path);$selected=@($plan|Where-Object {$Source -contains $_.Source -and $_.Risk -eq 'YELLOW'})
    if(!$selected){return [pscustomobject]@{Status='NoSafeSelection';Moved=@();Message='No selected files passed the safety checks.'}}
    if(!(Confirm-ThreeTimes -Action 'Moving selected files by category' -Summary "$($selected.Count) selected file(s) will be moved.")){return [pscustomobject]@{Status='Cancelled';Moved=@()}}
    $moved=[Collections.Generic.List[object]]::new();$skipped=[Collections.Generic.List[object]]::new();$i=0
    foreach($item in $selected){$i++;Write-UserProgress 'Moving selected files' $i $selected.Count "Moving file $i of $($selected.Count)";try{New-Item -ItemType Directory -Path (Split-Path $item.Destination -Parent) -Force|Out-Null;Move-Item -LiteralPath $item.Source -Destination $item.Destination -ErrorAction Stop;$moved.Add($item)}catch{$skipped.Add([pscustomobject]@{Source=$item.Source;Reason=$_.Exception.Message})}}
    Write-Progress -Activity 'Moving selected files' -Completed;Add-RapihkanHistory 'SelectedOrganization' 'Complete' "$($moved.Count) file(s) organized" @($moved)|Out-Null;[pscustomobject]@{Status='Complete';Moved=@($moved);Skipped=@($skipped)}
}