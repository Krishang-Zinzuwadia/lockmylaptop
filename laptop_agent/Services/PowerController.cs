using System.Runtime.InteropServices;

namespace LockMyLaptop.LaptopAgent.Services;

public sealed class PowerController
{
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool LockWorkStation();

    public bool Lock() => LockWorkStation();

    public bool Sleep()
    {
        // Phase 1 placeholder. Phase 3 implements real sleep behavior.
        return true;
    }
}
