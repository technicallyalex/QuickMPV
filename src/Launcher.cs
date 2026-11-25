using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

class Launcher {
    const uint SetIconMessage = 0x0080;

    [DllImport("user32.dll", SetLastError = true)]
    static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr kind, IntPtr icon,
        uint flags, uint timeout, out IntPtr result);

    static void ApplyWindowIcon(Process engine, string launcher, string iconPath) {
        if (!File.Exists(iconPath)) return;
        var wait = Stopwatch.StartNew();
        IntPtr window = IntPtr.Zero;
        while (!engine.HasExited && wait.ElapsedMilliseconds < 10000) {
            engine.Refresh();
            window = engine.MainWindowHandle;
            if (window != IntPtr.Zero) break;
            Thread.Sleep(75);
        }
        if (window == IntPtr.Zero) return;
        using (var small = new Icon(iconPath, SystemInformation.SmallIconSize))
        using (var large = new Icon(iconPath, SystemInformation.IconSize)) {
            IntPtr previous;
            SendMessageTimeout(window, SetIconMessage, IntPtr.Zero, small.Handle, 2, 1000, out previous);
            SendMessageTimeout(window, SetIconMessage, new IntPtr(1), large.Handle, 2, 1000, out previous);
            try { ShellIdentity.ApplyWindow(window,launcher,iconPath); }
            catch (SystemException error) { Debug.WriteLine(error.Message); }
            // The icons belong to this process and must remain valid while mpv owns the window.
            engine.WaitForExit();
        }
    }

    // Windows command-line quoting, including trailing backslashes and embedded quotes.
    static string Quote(string s) {
        var b = new System.Text.StringBuilder("\"");
        int n = 0;
        foreach (char c in s) {
            if (c == '\\') { n++; continue; }
            if (c == '"') { b.Append('\\', n * 2 + 1); b.Append(c); n = 0; continue; }
            b.Append('\\', n); n = 0; b.Append(c);
        }
        b.Append('\\', n * 2); b.Append('"'); return b.ToString();
    }
    [STAThread] static void Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string arguments = "--config-dir=" + Quote(Path.Combine(root, "portable_config")) + " --";
        try {
            ShellIdentity.ApplyProcess();
            if (!File.Exists(Path.Combine(root,"mpv.exe")) || !File.Exists(Path.Combine(root,"mpv.com"))) {
                string powershell=Path.Combine(Environment.SystemDirectory,@"WindowsPowerShell\v1.0\powershell.exe");
                string updater=Path.Combine(root,@"portable_config\update-mpv.ps1");
                Process.Start(new ProcessStartInfo(powershell,"-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "+Quote(updater)) {
                    UseShellExecute=false, WorkingDirectory=root, CreateNoWindow=true
                });
                return;
            }
            foreach (string arg in args) {
                Uri uri;
                bool isRemoteUri = Uri.TryCreate(arg, UriKind.Absolute, out uri) && !uri.IsFile;
                string media = isRemoteUri ? arg : Path.GetFullPath(arg);
                arguments += " " + Quote(media);
            }
            using (Process engine = Process.Start(new ProcessStartInfo(Path.Combine(root, "mpv.exe"), arguments) {
                UseShellExecute = false, WorkingDirectory = root, CreateNoWindow = true
            })) {
                try { ApplyWindowIcon(engine, Path.Combine(root,"QuickMPV.exe"), Path.Combine(root,"QuickMPV.ico")); }
                catch (SystemException error) { Debug.WriteLine(error.Message); }
            }
        } catch (Exception e) { MessageBox.Show(e.Message, "QuickMPV could not start"); }
    }
}
