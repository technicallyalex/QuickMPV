param([switch]$AppOnly)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$stage = Join-Path $root 'build\setup-payload'
$archive = Join-Path $root ('build\setup-payload' + $(if ($AppOnly) { '-app-only' }) + '.zip')
$setup = Join-Path $root $(if ($AppOnly) { 'QuickMPV-Shareable-Setup.exe' } else { 'QuickMPV-Setup.exe' })
$sevenZip = Join-Path $env:ProgramFiles '7-Zip\7z.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'

$files = @('QuickMPV.exe','QuickMPV.ico','mpv.exe','mpv.com','d3dcompiler_43.dll','README.txt',
    'licenses\GPL-2.0.txt','licenses\GPL-3.0.txt','licenses\QuickMPV-MIT.txt',
    'portable_config\mpv.conf','portable_config\input.conf','portable_config\open-file.ps1',
    'portable_config\quick-audio.lua','portable_config\quick-panel.lua','portable_config\quick-rtx.conf',
    'portable_config\quick-settings.lua','portable_config\quick-stats.lua','portable_config\quick-thumb-worker.lua',
    'portable_config\quick-thumbnails.lua','portable_config\quick-theme.lua',
    'portable_config\update-mpv.ps1','portable_config\scripts\quick-ui.lua')
if ($AppOnly) { $files = @($files | Where-Object { $_ -notin 'mpv.exe','mpv.com','d3dcompiler_43.dll' }) }

foreach ($file in $files) {
    $destination = Join-Path $stage $file
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root "portable\$file") -Destination $destination -Force
}
Copy-Item -LiteralPath (Join-Path $root 'src\Uninstall-QuickMPV.ps1') -Destination $stage -Force
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
Push-Location $stage
try {
    & $sevenZip a -tzip $archive @files 'Uninstall-QuickMPV.ps1' -mx=5
    if ($LASTEXITCODE) { throw 'Installer payload compression failed.' }
} finally { Pop-Location }

& $compiler /nologo /target:winexe /platform:x64 /reference:System.Windows.Forms.dll /reference:Microsoft.CSharp.dll `
    "/win32icon:$root\portable\QuickMPV.ico" `
    "/win32manifest:$root\src\QuickMPV.manifest" `
    /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll `
    "/resource:$archive,QuickMPV.Payload" "/out:$setup" "$root\src\Setup.cs" "$root\src\ShellIdentity.cs"
if ($LASTEXITCODE) { throw 'Windows installer compilation failed.' }
Get-Item -LiteralPath $setup | Select-Object Name,Length
