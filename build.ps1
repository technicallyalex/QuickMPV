$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:winexe /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/win32icon:$root\portable\QuickMPV.ico" "/win32manifest:$root\src\QuickMPV.manifest" "/out:$root\portable\QuickMPV.exe" "$root\src\Launcher.cs" "$root\src\ShellIdentity.cs"
if ($LASTEXITCODE -ne 0) { throw 'Launcher compilation failed' }
Write-Output 'Built portable\QuickMPV.exe'
