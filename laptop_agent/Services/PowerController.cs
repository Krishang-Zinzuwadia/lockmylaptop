using System.Runtime.InteropServices;
using System.Diagnostics;

namespace LockMyLaptop.LaptopAgent.Services;

public sealed class PowerController
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool LockWorkStation();

    [DllImport("PowrProf.dll", SetLastError = true)]
    private static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);

    public bool Lock() => LockWorkStation();

    public bool Sleep()
    {
        return SetSuspendState(false, true, true);
    }

    public bool Shutdown()
    {
        try
        {
            var info = new ProcessStartInfo
            {
                FileName = "shutdown",
                Arguments = "/s /t 0 /f",
                CreateNoWindow = true,
                UseShellExecute = false,
            };

            Process.Start(info);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
