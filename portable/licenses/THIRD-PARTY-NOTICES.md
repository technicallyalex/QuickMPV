# Third-party notices

The QuickMPV source and shareable installer include the original launcher, interface, scripts, and icon under the [MIT License](QuickMPV-MIT.txt). The third-party tools below are supplied by their own publishers or by Windows.

## Playback engine

- **mpv** is developed by the mpv project and builds on MPlayer and mplayer2. mpv's default source license is GPL-2.0-or-later. Upstream documents the terms for LGPL-only builds and individual files. [mpv source](https://github.com/mpv-player/mpv) · [Copyright and licensing](https://github.com/mpv-player/mpv/blob/master/Copyright) · [GPL 2.0](GPL-2.0.txt) · [GPL 3.0](GPL-3.0.txt)
- **Windows builds of mpv** are provided by shinchiro. After approval, QuickMPV downloads the selected x64 archive directly from that project's GitHub release. The version and commit printed by `mpv.com --no-config --version` identify the installed build. The upstream build recipe describes its dependencies and configuration. [Downloads](https://github.com/shinchiro/mpv-winbuild-cmake/releases) · [Build recipe](https://github.com/shinchiro/mpv-winbuild-cmake)
- **FFmpeg**, from the FFmpeg project, provides decoding and thumbnail filters through mpv. FFmpeg is LGPL-2.1-or-later by default, with GPL terms applying to builds that enable GPL components. The release configuration determines the applicable terms. [FFmpeg licensing](https://ffmpeg.org/legal.html) · [FFmpeg source](https://github.com/FFmpeg/FFmpeg)
- **libplacebo** and **libass** provide video processing and subtitle rendering in mpv. [libplacebo source and license](https://github.com/haasn/libplacebo/blob/master/LICENSE) · [libass source and license](https://github.com/libass/libass/blob/master/COPYING)

The repository and shareable installer exclude `mpv.exe`, `mpv.com`, and `d3dcompiler_43.dll`. The engine-inclusive build target uses local copies for personal use. Anyone distributing that build is responsible for the applicable third-party notices, corresponding source, and redistribution permissions for the exact binaries they supply.

## Build and system tools

- **7-Zip**, by Igor Pavlov, compresses the installer payload during the build. Its licensing includes LGPL and additional terms for certain components. The build uses an independently installed copy. [7-Zip licensing](https://github.com/ip7z/7zip/blob/main/DOC/License.txt)
- **Microsoft .NET Framework and Windows PowerShell** provide the C# compiler, Windows Forms, and scripting support. QuickMPV uses the Windows-installed tools and system components. [Microsoft .NET Framework](https://learn.microsoft.com/en-us/dotnet/framework/get-started/overview) · [Windows PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/windows-powershell/overview)
- **Windows `tar.exe`**, based on libarchive's `bsdtar`, extracts the independently downloaded mpv archive. [Microsoft Windows tar documentation](https://learn.microsoft.com/en-us/windows/tar/) · [libarchive copyright and licenses](https://github.com/libarchive/libarchive/blob/master/COPYING)

## Timeline preview credit

**Thumbfast**, by po5 and contributors, inspired the use of a separate mpv process to generate timeline frames. QuickMPV uses its own Lua scripts for thumbnail generation and display. Thumbfast's script and configuration are distributed by the Thumbfast project under MPL 2.0. [Thumbfast project](https://github.com/po5/thumbfast) · [MPL 2.0](https://github.com/po5/thumbfast/blob/master/LICENSE)
