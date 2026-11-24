. "$PSScriptRoot\Common-Utilities.ps1"
. "$PSScriptRoot\Junk-Scanner.ps1"
. "$PSScriptRoot\Quarantine-Manager.ps1"
. "$PSScriptRoot\User-Safety.ps1"
function Invoke-SafeCleanup {
 [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
 param([switch]$Apply,[int]$MinimumAgeDays=7)
 $items=@(Find-JunkCandidates -MinimumAgeDays $MinimumAgeDays);$plan=New-OperationManifest -Items $items -Type 'SafeCleanup'
 if(!$Apply){return [pscustomobject]@{Mode='Preview';PlanPath=$plan;Candidates=$items;EstimatedBytes=($items|Measure-Object SizeBytes -Sum).Sum;Message='No files have been moved.'}}
 $total=@($items).Count;$bytes=($items|Measure-Object SizeBytes -Sum).Sum
 if($total -eq 0){return [pscustomobject]@{Mode='Complete';PlanPath=$plan;Moved=@();Message='No safe temporary files were found to clean up.'}}
 if(!(Confirm-ThreeTimes -Action 'Moving temporary files to Quarantine' -Summary "$total file(s), about $(Format-ByteSize $bytes), can be restored.")){return [pscustomobject]@{Mode='Cancelled';PlanPath=$plan;Moved=@();Message='No files were changed.'}}
 $moved=[Collections.Generic.List[object]]::new();$skipped=[Collections.Generic.List[object]]::new();$index=0
 foreach($item in $items){$index++;Write-UserProgress 'Cleaning up temporary files' $index $total "Checking file $index of $total";try{$destination=Move-FileToQuarantine -Path $item.Path -Reason 'Rapihkan Win11 recommendation' -Confirm:$false;if($destination){$moved.Add([pscustomobject]@{Source=$item.Path;Quarantine=$destination;SizeBytes=$item.SizeBytes})}}catch{$skipped.Add([pscustomobject]@{Path=$item.Path;Reason=$_.Exception.Message})}}
 Write-Progress -Activity 'Cleaning up temporary files' -Completed
 [pscustomobject]@{Mode='Complete';PlanPath=$plan;Moved=@($moved);Skipped=@($skipped);Message="$($moved.Count) file(s) moved to Quarantine. Files were not permanently deleted."}
}