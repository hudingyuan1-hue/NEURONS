param(
    [Parameter(Mandatory=$true)][string]$Executable,
    [Parameter(Mandatory=$true)][string]$ReportDirectory,
    [Parameter(Mandatory=$true)][string]$SaveRoot
)
$ErrorActionPreference = 'Stop'
$exePath = (Resolve-Path -LiteralPath $Executable).Path
$reportPath = [IO.Path]::GetFullPath($ReportDirectory)
New-Item -ItemType Directory -Force -Path $reportPath | Out-Null
if (-not ('NeuronsOwnedWindow' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class NeuronsOwnedWindow {
    private delegate bool Callback(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool EnumWindows(Callback callback, IntPtr parameter);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder text, int size);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr window, StringBuilder text, int size);
    public static string Seen = "";
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
    public static IntPtr Find(uint process) {
        IntPtr result = IntPtr.Zero; Seen = "";
        EnumWindows((window, unused) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            if(owner != process) return true;
            var name = new StringBuilder(256); GetClassName(window, name, 256);
            var title = new StringBuilder(256); GetWindowText(window, title, 256);
            Seen += name.ToString()+":"+title.ToString()+";";
            if(title.ToString().Contains("NEURONS") || name.ToString().StartsWith("Godot_Window")) { result=window; return false; }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@
}
$outLog = Join-Path $reportPath 'normal_exe_stdout.txt'
$errLog = Join-Path $reportPath 'normal_exe_stderr.txt'
$run = $null
$result = @{scope='Actual Windows release EXE, normal main scene and OS WM_CLOSE; no custom script/project override; Dummy audio, no full gameplay or listening claim'}
try {
    $run = Start-Process -FilePath $exePath -ArgumentList @('--rendering-driver','opengl3','--audio-driver','Dummy','--',('--save-root='+$SaveRoot)) -WorkingDirectory ([IO.Path]::GetDirectoryName($exePath)) -WindowStyle Hidden -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
    $window = [IntPtr]::Zero
    for ($attempt=0; $attempt -lt 100; $attempt++) {
        if ($run.HasExited) { break }
        $window = [NeuronsOwnedWindow]::Find([uint32]$run.Id)
        if ($window -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 50
    }
    if ($window -eq [IntPtr]::Zero) { $result.owned_window_classes=[NeuronsOwnedWindow]::Seen;throw 'No owned Godot game window was created' }
    Start-Sleep -Milliseconds 350
    $result.window_created = $true
    $result.close_message_sent = [NeuronsOwnedWindow]::PostMessage($window,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)
    $result.closed_normally = $run.WaitForExit(5000)
    if ($result.closed_normally) { $result.exit_code = $run.ExitCode }
    $result.stderr = Get-Content -LiteralPath $errLog -Raw
    $result.passed = $result.closed_normally -and $result.exit_code -eq 0 -and [string]::IsNullOrWhiteSpace($result.stderr)
} catch {
    $result.passed = $false
    $result.error = $_.Exception.Message
} finally {
    if ($run -and -not $run.HasExited -and $run.Path -eq $exePath) { Stop-Process -Id $run.Id }
    $result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reportPath 'normal_exe_startup.json') -Encoding UTF8
}
$result | ConvertTo-Json -Depth 5
if (-not $result.passed) { exit 1 }
