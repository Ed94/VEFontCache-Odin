if ($env:VCINSTALLDIR) {
    return
}

$ErrorActionPreference = "Stop"

# Use vswhere to find the latest Visual Studio installation
$vswhere_out = & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath
if ($null -eq $vswhere_out) {
    Write-Host "ERROR: Visual Studio installation not found"
    exit 1
}

# Find Launch-VsDevShell.ps1 in the Visual Studio installation
$vs_path     = $vswhere_out
$vs_devshell = Join-Path $vs_path "\Common7\Tools\Launch-VsDevShell.ps1"

if ( -not (Test-Path $vs_devshell) ) {
    Write-Host "ERROR: Launch-VsDevShell.ps1 not found in Visual Studio installation"
    Write-Host Tested path: $vs_devshell
    exit 1
}

# Launch the Visual Studio Developer Shell
Push-Location
write-host @args
& $vs_devshell @args
Pop-Location
