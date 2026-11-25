QuickMPV — portable Windows preview
==================================

START
Double-click QuickMPV.exe. No installer or administrator rights are needed.
Keep the entire folder together. You can move it to another folder or USB drive.
Windows 10/11 x64; uses Windows' built-in .NET Framework 4.x for the tiny launcher.
Alternatively run mpv.exe directly from this folder.
QuickMPV-Setup.exe installs the app for your Windows account and adds a Start
menu shortcut and an uninstall entry in Windows Settings. Uninstall keeps your
preferences and mpv.conf. The installer does not register media file types.

MPV ENGINE UPDATES
Open Preferences > Advanced > Check for MPV updates.
The shareable installer downloads the MPV engine on first launch.
QuickMPV checks shinchiro's GitHub release feed for a newer Windows x64 MPV
build. Review the build before downloading. Close QuickMPV when prompted to
apply; you can reopen it from the updater. The update replaces the engine
only and keeps your QuickMPV preferences. It can also update the portable copy.

OPEN MEDIA
Drop files into the window, click Open File, or press Ctrl+O.
You can also drop media onto QuickMPV.exe or pass filenames on its command line.
Selecting multiple files creates a playback queue; use the options menu to move
to the previous or next file.

CONTROLS
Space / click picture       Play or pause
Drag timeline              Scrub
Double-click / F            Fullscreen
Escape                     Dismiss menu or leave fullscreen
Left / Right               Back / forward 5 seconds
Shift+Left / Shift+Right    Previous / next frame
Up / Down                  Volume
M                          Mute
L                          Loop
Ctrl+O                     Open native file picker
Ctrl+Q / Ctrl+W             Quit
Right-click / ...           Playback options
Ctrl+,                     Preferences
Ctrl+I                     Toggle playback stats

The floating controls hide after 2.5 seconds while playing and return when you
move the pointer. They stay visible when paused. Drag the QuickMPV title bar to
move the window, or double-click the title to maximize or restore it. Its three
buttons minimize, maximize or restore, and close. Use the playback
controls or F for fullscreen. The playback menu also offers actual size, fit
window, audio and subtitle cycling, and stay on top.
The window fits each video's aspect ratio by default. Change this under
Preferences > Video > Resize window to fit video.
Controls follow the monitor's Windows display scale. On small windows the
layout compacts and scales down as needed to keep controls within the window.

PLAYBACK STATS AND AUDIO TRACKS
Use Playback stats in the right-click menu or press Ctrl+I. The overlay shows
resolution, frame rate, codecs, available bitrates, audio output, and dropped
frames. When a filter changes video resolution, both resolutions are shown.
Use Mix all audio tracks in the right-click menu to switch modes for this
session. Set Preferences > Audio > Audio track mode to make mixing the default.
Tracks are mixed at equal levels with normalization. Files with one audio track
play normally. A custom MPV complex filter graph takes precedence over mixing.

TIMELINE PREVIEWS
Hover over the timeline or drag it to see a frame and timestamp. QuickMPV starts
one background preview decoder when a seekable local video opens and reuses it
for each preview, following the approach used by Thumbfast. Audio and unsupported
sources show the timestamp. Playback > Timeline thumbnails turns previews off.

PREFERENCES
Open Preferences from the playback menu or press Ctrl+,. Choose Playback,
Video, Audio, Subtitles, Appearance, or Advanced, then select a setting and its value.
Appearance > Interface theme switches between Navy and Periwinkle, Violet,
Teal, Black, Gray, and White. The title bar uses the same theme.
Escape goes back from the value list or closes Preferences. The panel shows
whether an option applies on the next file or requires restarting QuickMPV.
Playback > Remember settings controls whether changes are saved. Turn it off to
make temporary changes and keep the previous saved preferences for next launch.
Turning it back on saves the changes from this session. Settings that require a
restart can only be changed while Remember settings is on.
Preferences are saved in portable_config/quick-preferences.conf. Advanced >
Open mpv.conf opens the base configuration for additional MPV options. Values
chosen in Preferences take precedence over matching entries in mpv.conf.
To undo a graphics change if QuickMPV cannot open, remove the gpu-context line
from quick-preferences.conf to return to the bundled OpenGL default.

RTX VIDEO AND HDR
In Preferences > Video > RTX and native HDR, choose RTX Super Resolution (2x),
RTX HDR (SDR to HDR), RTX Super Resolution + RTX HDR, Native HDR output, or Off. Restart
QuickMPV after changing modes. The Super Resolution modes use NVIDIA's 2x
setting from the original MPV installation. RTX HDR converts SDR video to HDR.
Native HDR output selects Direct3D 11 without applying either NVIDIA filter.
These modes use the bundled Direct3D 11 renderer and decoder settings. Off
restores your regular renderer and decoder preferences. Enable the NVIDIA
features in NVIDIA app > System > Video and enable Windows HDR for HDR output
on a compatible display. To recover from an incompatible renderer, remove
the profile=quick-... line from portable_config/quick-preferences.conf.

PORTABILITY
Settings live in portable_config next to the player. This preview does not
install file associations, change your existing MPV settings, or register itself.
Its configuration uses Windows OpenGL because the default Direct3D renderer
failed during startup on the test machine. Hardware decoding remains automatic.
The folder and ZIP contain the playback engine; no separate MPV download needed.

SCOPE
This is an original QuickTime-inspired MPV interface, not an Apple product or
a pixel-for-pixel QuickTime clone. No Apple assets are bundled. This preview
implements playback, not recording, trimming, export, AirPlay, or other macOS
services. Menus cycle available track IDs rather than showing named track lists.
The file picker requires Windows PowerShell and Windows Forms.

VALIDATION
Tested using a generated H.264/AAC clip: GPU video decoding, WASAPI audio output,
exact seek, actual on-screen play/pause button commands, scrubber interaction,
volume/mute, playback speed, loop, fullscreen, Escape, menu and idle state.
Playback and menu rendering were visually inspected using MPV screenshots.
The launcher opened a clip by relative path from a relocated folder with spaces.
Ctrl+O launched the native picker helper, and a simulated two-file selection
verified loading the first clip and queuing the second. Selecting files in the
native dialog and dropping files from Explorer remain manual checks.

ENGINE / SOURCE
After a shareable install, the launcher downloads the engine directly from
shinchiro's mpv Windows builds on first launch after you approve. Run mpv.com --no-config
--version to identify the engine installed on your system.
mpv project: https://mpv.io/
Windows builds: https://github.com/shinchiro/mpv-winbuild-cmake/releases
QuickMPV source: https://github.com/technicallyalex/QuickMPV
See licenses/THIRD-PARTY-NOTICES.md for attribution and upstream license links.
The original interface and launcher code are MIT-licensed. The Lua UI and
configuration are editable in portable_config.
