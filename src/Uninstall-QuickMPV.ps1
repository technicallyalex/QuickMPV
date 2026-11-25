$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$ui = [System.Windows.Forms.MessageBox]
$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
$expected = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\QuickMPV'
try {
    if ($root -ne $expected) { throw 'Run uninstall from the installed copy of QuickMPV.' }
    if ($ui::Show('Remove QuickMPV? Your preferences will be kept.', 'QuickMPV', 'OKCancel') -ne 'OK') { exit }
    $manifest = Join-Path $root 'install-files.txt'
    $paths = foreach ($name in [IO.File]::ReadAllLines($manifest)) {
        if ($name -in 'portable_config\mpv.conf','portable_config\quick-preferences.conf') { continue }
        if ([IO.Path]::IsPathRooted($name) -or $name.Contains(':')) { throw 'Invalid uninstall manifest.' }
        $path = [IO.Path]::GetFullPath((Join-Path $root $name))
        if (!$path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid uninstall manifest.' }
        $path
    }
    if (Get-Process -Name mpv -ErrorAction SilentlyContinue | Where-Object Path -eq (Join-Path $root 'mpv.exe')) {
        throw 'Close QuickMPV before uninstalling.'
    }
    foreach ($path in $paths) { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
    [IO.File]::Delete($manifest)
    [IO.File]::Delete((Join-Path ([Environment]::GetFolderPath('Programs')) 'QuickMPV.lnk'))
    [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey('Software\Microsoft\Windows\CurrentVersion\Uninstall\QuickMPV',$false)
    $ui::Show('QuickMPV was removed.', 'QuickMPV') | Out-Null
} catch { $ui::Show($_.Exception.Message, 'QuickMPV uninstall', 'OK', 'Error') | Out-Null }
