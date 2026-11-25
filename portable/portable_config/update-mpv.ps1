[CmdletBinding()]
param([switch]$FunctionsOnly)

function Get-EngineVersion($directory) {
    $console = Join-Path $directory 'mpv.com'
    $output = (& $console --no-config --version) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $output -notmatch '(?m)^mpv (\S+)') { throw 'Could not read the MPV engine version.' }
    $version = $Matches[1]
    $commit = if ($version -match '-g([0-9a-f]{7,40})') { $Matches[1] } else { '' }
    $date = if ($output -match '(?m)^\s*built on (\S+\s+\d+\s+\d{4})') {
        [DateTime]::Parse($Matches[1], [Globalization.CultureInfo]::InvariantCulture).ToString('yyyyMMdd')
    } else { '' }
    [pscustomobject]@{Version=$version; Commit=$commit; Date=$date}
}

function Get-ReleaseAsset($release) {
    if ($release.draft -or $release.prerelease -or $release.tag_name -cnotmatch '^\d{8}$') { throw 'Unexpected MPV release metadata.' }
    $root = 'https://github.com/shinchiro/mpv-winbuild-cmake/releases/download/' + $release.tag_name + '/'
    $candidates = foreach ($asset in $release.assets) {
        if ($asset.name -cmatch '^mpv-x86_64-(\d{8})-git-([0-9a-f]{7,40})\.7z$') {
            $date,$commit = $Matches[1],$Matches[2]
            $url = $root + $asset.name
            if ($asset.browser_download_url -cne $url -or $asset.state -cne 'uploaded') { continue }
            if ($asset.digest -match '^sha256:([0-9a-f]{64})$' -and $asset.size -gt 0 -and $asset.size -lt 250MB) {
                [pscustomobject]@{Date=$date; Commit=$commit; Url=$url; Hash=$Matches[1]; Size=[long]$asset.size}
            }
        }
    }
    $candidate = $candidates | Sort-Object Date -Descending | Select-Object -First 1
    if (!$candidate) { throw 'The latest release did not include a verifiable Windows x64 MPV build.' }
    $candidate
}

function Test-CommitMatch($a,$b) {
    return [bool]($a -and $b -and ($a.StartsWith($b) -or $b.StartsWith($a)))
}

function Expand-Engine($archive,$stage,$asset) {
    if ((Get-Item -LiteralPath $archive).Length -ne $asset.Size -or
        (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $asset.Hash) {
        throw 'The download did not match the published SHA-256 digest.'
    }
    $tar = Join-Path $env:WINDIR 'System32\tar.exe'
    foreach ($name in 'mpv.exe','mpv.com') {
        $start = [Diagnostics.ProcessStartInfo]::new($tar, '-xOf "' + $archive + '" -- ' + $name)
        $start.UseShellExecute = $false
        $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true
        $process = [Diagnostics.Process]::Start($start)
        try {
            $path = Join-Path $stage $name
            $file = [IO.File]::Open($path,'CreateNew','Write','None')
            try { $process.StandardOutput.BaseStream.CopyTo($file) } finally { $file.Dispose() }
            $process.WaitForExit()
            if ($process.ExitCode -ne 0 -or (Get-Item -LiteralPath $path).Length -lt 1024) { throw "Could not extract $name from the MPV release." }
        } finally { $process.Dispose() }
    }
    $engine = Get-EngineVersion $stage
    if (!(Test-CommitMatch $engine.Commit $asset.Commit)) { throw 'The downloaded engine reports a different commit from the release asset.' }
    $engine
}

function Install-Engine($root,$stage) {
    $applied = @()
    try {
        foreach ($name in 'mpv.exe','mpv.com') {
            $target = Join-Path $root $name
            if ([IO.File]::Exists($target)) {
                [IO.File]::Replace((Join-Path $stage $name),$target,(Join-Path $stage ($name+'.bak')))
            } else {
                [IO.File]::Move((Join-Path $stage $name),$target)
            }
            $applied += $name
        }
        $version = Get-EngineVersion $root
    } catch {
        foreach ($name in $applied) {
            $backup = Join-Path $stage ($name+'.bak')
            $target = Join-Path $root $name
            if ([IO.File]::Exists($backup)) { [IO.File]::Replace($backup,$target,[NullString]::Value) }
            else { [IO.File]::Delete($target) }
        }
        throw
    }
    foreach ($name in $applied) { [IO.File]::Delete((Join-Path $stage ($name+'.bak'))) }
    $version
}

if ($FunctionsOnly) { return }
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
$ui = [System.Windows.Forms.MessageBox]
$root = Split-Path -Parent $PSScriptRoot
$stage = $null
$lock = $null
$checking = $null
try {
    $lock = [IO.File]::Open((Join-Path $root '.mpv-update.lock'),'OpenOrCreate','ReadWrite','None')
    $checking = New-Object System.Windows.Forms.Form
    $checking.Text = 'MPV Update'
    $checking.ClientSize = New-Object Drawing.Size(370,85)
    $checking.StartPosition = 'CenterScreen'
    $checking.ControlBox = $false
    $status = New-Object System.Windows.Forms.Label
    $status.TextAlign = 'MiddleCenter'
    $status.Dock = 'Fill'
    $status.Text = 'Checking for MPV updates...'
    $checking.Controls.Add($status)
    $checking.Show()
    [System.Windows.Forms.Application]::DoEvents()
    $hasEngine = (Test-Path -LiteralPath (Join-Path $root 'mpv.exe')) -and (Test-Path -LiteralPath (Join-Path $root 'mpv.com'))
    $current = if ($hasEngine) { Get-EngineVersion $root }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{'User-Agent'='QuickMPV-Updater'; Accept='application/vnd.github+json'}
    $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest' -Headers $headers -UseBasicParsing -TimeoutSec 20
    $asset = Get-ReleaseAsset $release
    $checking.Hide()
    if ($current -and !$current.Date) { throw 'Could not determine the date of the installed MPV build.' }
    if ($current -and ((Test-CommitMatch $asset.Commit $current.Commit) -or $asset.Date -lt $current.Date)) {
        $ui::Show("No newer MPV build is available.`nInstalled: $($current.Version)",'MPV Update') | Out-Null
        return
    }
    $installedVersion = if ($current) { "Installed: $($current.Version)" } else { 'First-time setup' }
    if ($ui::Show("Download and install MPV build $($asset.Date) ($($asset.Commit))?`n$installedVersion",'MPV Update','YesNo','Question') -ne 'Yes') { return }
    $stage = Join-Path $root ('.mpv-update-' + [Guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($stage) | Out-Null
    $status.Text = 'Downloading and verifying MPV...'
    $checking.Show()
    [System.Windows.Forms.Application]::DoEvents()
    $archive = Join-Path $stage 'mpv.7z'
    Invoke-WebRequest -Uri $asset.Url -Headers $headers -UseBasicParsing -TimeoutSec 180 -OutFile $archive
    $new = Expand-Engine $archive $stage $asset
    $checking.Hide()
    $enginePath = Join-Path $root 'mpv.exe'
    while (Get-Process -Name mpv -ErrorAction SilentlyContinue | Where-Object Path -eq $enginePath) {
        if ($ui::Show('Close this copy of QuickMPV, then click Retry to apply the update.','MPV Update','RetryCancel') -ne 'Retry') { return }
    }
    $installed = Install-Engine $root $stage
    if ($ui::Show("Installed $($installed.Version). Open QuickMPV now?",'MPV Update','YesNo','Information') -eq 'Yes') {
        Start-Process -FilePath (Join-Path $root 'QuickMPV.exe')
    }
} catch {
    if ($checking) { $checking.Hide() }
    $ui::Show($_.Exception.Message,'MPV Update','OK','Error') | Out-Null
} finally {
    if ($checking) { $checking.Dispose() }
    if ($lock) { $lock.Dispose() }
    if ($stage -and [IO.Directory]::Exists($stage) -and !(Get-ChildItem -LiteralPath $stage -Filter '*.bak')) {
        [IO.Directory]::Delete($stage,$true)
    }
}
