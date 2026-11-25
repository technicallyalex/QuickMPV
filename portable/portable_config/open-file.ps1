Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'Open media — QuickMPV'
$dialog.Filter = 'Media files|*.mp4;*.mov;*.mkv;*.webm;*.avi;*.m4v;*.mp3;*.wav;*.flac;*.aac;*.m4a;*.ogg;*.m2ts;*.mts;*.wmv|All files|*.*'
$dialog.Multiselect = $true
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    ConvertTo-Json -InputObject @($dialog.FileNames) -Compress
}
$dialog.Dispose()
