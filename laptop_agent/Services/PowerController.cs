using System.Runtime.InteropServices;

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
}
