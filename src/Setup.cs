using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class Setup {
    const string UninstallKey = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\QuickMPV";
    const string Manifest = "install-files.txt";
    const string Preferences = @"portable_config\quick-preferences.conf";

    internal static string SafePath(string root, string relative) {
        string prefix = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        string target = Path.GetFullPath(Path.Combine(prefix, relative));
        if (!target.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || Path.IsPathRooted(relative) || relative.Contains(":"))
            throw new InvalidDataException("Invalid installer file path");
        return target;
    }

    internal static void InstallFiles(string target, Stream payload) {
        Directory.CreateDirectory(target);
        string stage = Path.Combine(target, ".setup-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stage);
        var files = new List<string>();
        var changed = new List<KeyValuePair<string,string>>();
        try {
            using (var zip = new ZipArchive(payload, ZipArchiveMode.Read)) {
                foreach (var entry in zip.Entries) {
                    if (String.IsNullOrEmpty(entry.Name)) continue;
                    string name = entry.FullName.Replace('/', '\\');
                    string path = SafePath(stage, name);
                    Directory.CreateDirectory(Path.GetDirectoryName(path));
                    entry.ExtractToFile(path);
                    files.Add(name);
                }
            }
            bool installed = File.Exists(Path.Combine(target, Manifest));
            bool keepEngine = installed && File.Exists(Path.Combine(target,"mpv.exe")) && File.Exists(Path.Combine(target,"mpv.com"));
            string prefs = SafePath(stage, Preferences);
            File.WriteAllText(prefs, "# Managed by QuickMPV Preferences.\r\n");
            files.Add(Preferences);
            var managed = files.FindAll(name => name != Preferences);
            // First launch of an engine-free build can add these files later.
            foreach (string name in new[] { "mpv.exe", "mpv.com" })
                if (!managed.Contains(name)) managed.Add(name);
            File.WriteAllLines(Path.Combine(stage, Manifest), managed);
            files.Add(Manifest);

            foreach (string name in files) {
                string path = SafePath(target, name);
                if ((keepEngine && (name == "mpv.exe" || name == "mpv.com")) ||
                    (name == @"portable_config\mpv.conf" && File.Exists(path)) ||
                    (name == Preferences && File.Exists(path))) continue;
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                string staged = SafePath(stage, name);
                string backup = File.Exists(path) ? Path.Combine(stage, Guid.NewGuid().ToString("N") + ".bak") : null;
                if (backup == null) File.Move(staged, path);
                else File.Replace(staged, path, backup);
                changed.Add(new KeyValuePair<string,string>(path, backup));
            }
        } catch {
            for (int i = changed.Count - 1; i >= 0; i--) {
                var entry = changed[i];
                if (entry.Value == null) File.Delete(entry.Key);
                else File.Replace(entry.Value, entry.Key, null);
            }
            throw;
        } finally {
            Directory.Delete(stage, true);
        }
    }

    static void Register(string target) {
        string launcher = Path.Combine(target, "QuickMPV.exe");
        string icon = Path.Combine(target, "QuickMPV.ico");
        string uninstall = Path.Combine(target, "Uninstall-QuickMPV.ps1");
        string powershell = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
        using (RegistryKey key = Registry.CurrentUser.CreateSubKey(UninstallKey)) {
            key.SetValue("DisplayName", "QuickMPV");
            key.SetValue("DisplayIcon", icon + ",0");
            key.SetValue("InstallLocation", target);
            key.SetValue("UninstallString", "\"" + powershell + "\" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"" + uninstall + "\"");
            key.SetValue("NoModify", 1, RegistryValueKind.DWord);
            key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
        }
        string shortcutPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "QuickMPV.lnk");
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell"));
        dynamic shortcut = shell.CreateShortcut(shortcutPath);
        shortcut.TargetPath = launcher;
        shortcut.IconLocation = icon + ",0";
        shortcut.WorkingDirectory = target;
        shortcut.Description = "QuickMPV";
        shortcut.Save();
        try { ShellIdentity.ApplyShortcut(shortcutPath); }
        catch (SystemException error) { Debug.WriteLine(error.Message); }
    }

    [STAThread] static void Main() {
        string target = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "QuickMPV");
        if (MessageBox.Show("Install QuickMPV for your Windows account?\n\n" + target,
            "QuickMPV Setup", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        try {
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("QuickMPV.Payload")) InstallFiles(target, stream);
            Register(target);
            if (MessageBox.Show("QuickMPV is installed. Open it now?", "QuickMPV Setup",
                MessageBoxButtons.YesNo, MessageBoxIcon.Information) == DialogResult.Yes)
                Process.Start(Path.Combine(target, "QuickMPV.exe"));
        } catch (Exception error) {
            MessageBox.Show(error.Message, "QuickMPV Setup", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
