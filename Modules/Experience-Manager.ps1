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
    $ink=[Drawing.Color]::FromArgb(7,26,43);$panel=[Drawing.Color]::FromArgb(13,41,64);$panelHover=[Drawing.Color]::FromArgb(18,57,83);$cyan=[Drawing.Color]::FromArgb(56,189,248);$mint=[Drawing.Color]::FromArgb(99,214,177);$text=[Drawing.Color]::FromArgb(234,246,252);$muted=[Drawing.Color]::FromArgb(166,201,219)
    $form=[Windows.Forms.Form]::new();$form.Text='Rapihkan Win11';$form.MinimumSize=[Drawing.Size]::new(920,620);$form.Size=[Drawing.Size]::new(1080,720);$form.StartPosition='CenterScreen';$form.BackColor=$ink;$form.Font=[Drawing.Font]::new('Segoe UI',9)
    $root=[Windows.Forms.TableLayoutPanel]::new();$root.Dock='Fill';$root.BackColor=$ink;$root.ColumnCount=2;$root.RowCount=1;$root.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Absolute',245));$root.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',100));$form.Controls.Add($root)
    $nav=[Windows.Forms.Panel]::new();$nav.Dock='Fill';$nav.BackColor=[Drawing.Color]::FromArgb(5,20,34);$nav.Padding=[Windows.Forms.Padding]::new(18,22,18,18);$root.Controls.Add($nav,0,0)
    $brand=[Windows.Forms.Label]::new();$brand.Text='RAPIHKAN`nWIN11';$brand.ForeColor=$text;$brand.Font=[Drawing.Font]::new('Segoe UI',18,[Drawing.FontStyle]::Bold);$brand.AutoSize=$true;$brand.Dock='Top';$nav.Controls.Add($brand)
    $tag=[Windows.Forms.Label]::new();$tag.Text='Portable PC care';$tag.ForeColor=$mint;$tag.Font=[Drawing.Font]::new('Segoe UI',9,[Drawing.FontStyle]::Bold);$tag.AutoSize=$true;$tag.Dock='Top';$tag.Padding=[Windows.Forms.Padding]::new(1,8,0,22);$nav.Controls.Add($tag)
    $navFlow=[Windows.Forms.FlowLayoutPanel]::new();$navFlow.Dock='Top';$navFlow.FlowDirection='TopDown';$navFlow.WrapContents=$false;$navFlow.AutoSize=$true;$nav.Controls.Add($navFlow)
    $content=[Windows.Forms.TableLayoutPanel]::new();$content.Dock='Fill';$content.Padding=[Windows.Forms.Padding]::new(28,24,28,24);$content.RowCount=3;$content.ColumnCount=1;$content.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',112));$content.RowStyles.Add([Windows.Forms.RowStyle]::new('Percent',100));$content.RowStyles.Add([Windows.Forms.RowStyle]::new('Absolute',38));$root.Controls.Add($content,1,0)
    $header=[Windows.Forms.Panel]::new();$header.Dock='Fill';$header.BackColor=$panel;$header.Padding=[Windows.Forms.Padding]::new(22,18,22,18);$content.Controls.Add($header,0,0)
    $heading=[Windows.Forms.Label]::new();$heading.Text='Good to see you.';$heading.ForeColor=$text;$heading.Font=[Drawing.Font]::new('Segoe UI',20,[Drawing.FontStyle]::Bold);$heading.AutoSize=$true;$heading.Dock='Top';$header.Controls.Add($heading)
    $subheading=[Windows.Forms.Label]::new();$subheading.Text='Pick a read-only check from the left. Results stay on this computer.';$subheading.ForeColor=$muted;$subheading.AutoSize=$true;$subheading.Dock='Top';$subheading.Padding=[Windows.Forms.Padding]::new(1,7,0,0);$header.Controls.Add($subheading)
    $status=[Windows.Forms.Label]::new();$status.Text='READY  •  no changes made';$status.ForeColor=$mint;$status.Font=[Drawing.Font]::new('Segoe UI',8,[Drawing.FontStyle]::Bold);$status.AutoSize=$true;$status.Dock='Bottom';$header.Controls.Add($status)
    $resultPanel=[Windows.Forms.Panel]::new();$resultPanel.Dock='Fill';$resultPanel.BackColor=$panel;$resultPanel.Padding=[Windows.Forms.Padding]::new(18);$resultPanel.Margin=[Windows.Forms.Padding]::new(0,18,0,14);$content.Controls.Add($resultPanel,0,1)
    $resultTitle=[Windows.Forms.Label]::new();$resultTitle.Text='Start with a check';$resultTitle.ForeColor=$text;$resultTitle.Font=[Drawing.Font]::new('Segoe UI',12,[Drawing.FontStyle]::Bold);$resultTitle.AutoSize=$true;$resultTitle.Dock='Top';$resultPanel.Controls.Add($resultTitle)
    $output=[Windows.Forms.RichTextBox]::new();$output.Dock='Fill';$output.ReadOnly=$true;$output.BorderStyle='None';$output.BackColor=[Drawing.Color]::FromArgb(8,31,49);$output.ForeColor=[Drawing.Color]::FromArgb(211,233,243);$output.Font=[Drawing.Font]::new('Cascadia Mono',10);$output.Text="Choose a check from the navigation.`n`nRapihkan Win11 only runs read-only checks in this window. File actions remain in the PowerShell menu and require three YES confirmations.";$output.Margin=[Windows.Forms.Padding]::new(0,14,0,0);$resultPanel.Controls.Add($output);$resultPanel.Controls.SetChildIndex($output,0)
    $footer=[Windows.Forms.Label]::new();$footer.Text='LOCAL ONLY   •   PORTABLE   •   REVIEW BEFORE ACTION';$footer.ForeColor=$muted;$footer.Font=[Drawing.Font]::new('Segoe UI',8,[Drawing.FontStyle]::Bold);$footer.Dock='Fill';$footer.TextAlign='MiddleLeft';$content.Controls.Add($footer,0,2)
    function Add-GuiNavButton([string]$Label,[string]$Description,[scriptblock]$Work) {
        $button=[Windows.Forms.Button]::new();$button.Text=$Label;$button.Tag=[pscustomobject]@{Description=$Description;Work=$Work};$button.FlatStyle='Flat';$button.FlatAppearance.BorderSize=0;$button.BackColor=$panel;$button.ForeColor=$text;$button.Font=[Drawing.Font]::new('Segoe UI',10,[Drawing.FontStyle]::Bold);$button.TextAlign='MiddleLeft';$button.Padding=[Windows.Forms.Padding]::new(14,0,8,0);$button.Size=[Drawing.Size]::new(208,43);$button.Margin=[Windows.Forms.Padding]::new(0,0,0,7)
        $button.Add_MouseEnter({param($sender,$event)$sender.BackColor=$panelHover});$button.Add_MouseLeave({param($sender,$event)$sender.BackColor=$panel})
        $button.Add_Click({param($sender,$event)$meta=$sender.Tag;$heading.Text=$sender.Text;$subheading.Text=$meta.Description;$resultTitle.Text="$($sender.Text) results";$status.Text='RUNNING  •  reading local system information';$status.ForeColor=$cyan;$form.UseWaitCursor=$true;try{$result=& $meta.Work;$output.Text=($result|Format-List *|Out-String);$status.Text='COMPLETE  •  no changes made';$status.ForeColor=$mint;Show-RapihkanNotification -Message "$($sender.Text) is complete."}catch{$output.Text="The check could not finish.`n`n$($_.Exception.Message)";$status.Text='CHECK FAILED  •  see details below';$status.ForeColor=[Drawing.Color]::Salmon}finally{$form.UseWaitCursor=$false}})
        $navFlow.Controls.Add($button)
    }
    Add-GuiNavButton 'System audit' 'Windows, storage, hardware, and baseline information.' {Invoke-SystemAudit}
    Add-GuiNavButton 'Performance' 'Current CPU, memory, and high-memory processes.' {Get-PerformanceBaseline}
    Add-GuiNavButton 'Windows health' 'Pending restart, Microsoft Defender, and firewall status.' {Get-SystemHealthCheck}
    Add-GuiNavButton 'Cache review' 'Local size review for browser and developer caches. Nothing is cleared.' {Get-CacheReview}
    Add-GuiNavButton 'Action history' 'Recent local actions recorded by Rapihkan Win11.' {Get-RapihkanHistory}
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