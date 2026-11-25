using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

internal static class ShellIdentity {
    const string AppId = "QuickMPV.Player";
    static readonly Guid AppUserModelKey = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");

    [StructLayout(LayoutKind.Sequential)]
    struct PropertyKey { public Guid Format; public uint Id; }

    [StructLayout(LayoutKind.Sequential)]
    struct PropVariant {
        public ushort Type, Reserved1, Reserved2, Reserved3;
        public IntPtr Data, Padding;
    }

    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore {
        void GetCount(out uint count);
        void GetAt(uint index, out PropertyKey key);
        void GetValue(ref PropertyKey key, out PropVariant value);
        void SetValue(ref PropertyKey key, ref PropVariant value);
        void Commit();
    }

    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    static extern int SetCurrentProcessExplicitAppUserModelID(string id);

    [DllImport("shell32.dll")]
    static extern int SHGetPropertyStoreForWindow(IntPtr window, ref Guid type, [MarshalAs(UnmanagedType.Interface)] out IPropertyStore store);

    [DllImport("shell32.dll", CharSet=CharSet.Unicode)]
    static extern void SHChangeNotify(uint eventId, uint flags, string item, IntPtr unused);

    static void Set(IPropertyStore store, uint id, string text) {
        var key = new PropertyKey { Format=AppUserModelKey, Id=id };
        var value = new PropVariant { Type=31, Data=Marshal.StringToCoTaskMemUni(text) };
        try { store.SetValue(ref key,ref value); }
        finally { Marshal.FreeCoTaskMem(value.Data); }
    }

    public static void ApplyProcess() { SetCurrentProcessExplicitAppUserModelID(AppId); }

    public static void ApplyWindow(IntPtr window, string launcher, string icon) {
        Guid iid=typeof(IPropertyStore).GUID;
        IPropertyStore store;
        Marshal.ThrowExceptionForHR(SHGetPropertyStoreForWindow(window,ref iid,out store));
        try {
            Set(store,2,"\""+launcher+"\"");
            Set(store,3,icon+",0");
            Set(store,4,"QuickMPV");
            Set(store,5,AppId);
        } finally { Marshal.ReleaseComObject(store); }
    }

    public static void ApplyShortcut(string path) {
        var link=Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("00021401-0000-0000-C000-000000000046")));
        try {
            var file=(IPersistFile)link;
            file.Load(path,2);
            var store=(IPropertyStore)link;
            Set(store,5,AppId);
            store.Commit();
            file.Save(path,true);
        } finally { Marshal.ReleaseComObject(link); }
        SHChangeNotify(0x2000,5,path,IntPtr.Zero);
    }
}
