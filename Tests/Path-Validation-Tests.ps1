param([string]$ToolkitRoot=(Split-Path -Parent $PSScriptRoot))
. "$ToolkitRoot\Modules\Common-Utilities.ps1"
if(Test-ProtectedPath 'C:\Windows\System32\notepad.exe'){ 'PASSED: protected Windows path' }else{throw 'Protected-path test failed'}
if(!(Test-ProtectedPath 'C:\Users\Public\sample.txt')){'PASSED: non-protected user path'}else{throw 'User path incorrectly protected'}