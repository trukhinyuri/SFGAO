<#
.SYNOPSIS
  This script uses SHParseDisplayName (Shell API) from PowerShell to parse
  a user-supplied path (including WSL, shell: URIs, UNC, etc.) and retrieve SFGAO flags.

.DESCRIPTION
  The script calls SHParseDisplayName to convert the given path into a PIDL (Pointer to an Item ID List),
  then retrieves SFGAO attributes that describe how the Windows Shell interprets the path.
  This includes whether it's a real file system object (SFGAO_FILESYSTEM), a file system ancestor,
  or just a virtual/container folder.

.NOTES
  Author: trukhinyuri <yuri@trukhin.com>
  Version: 1.0

.EXAMPLE
  PS C:\> .\check.ps1
  Enter a path to check (e.g. '\\wsl$\Ubuntu' or 'C:\Windows' or 'shell:PicturesLibrary'): \\wsl$\Ubuntu

  Path: \\wsl$\Ubuntu
  SHParseDisplayName failed (HRESULT = 0x80070043)

.EXAMPLE
  PS C:\> .\check.ps1
  Enter a path to check: shell:PicturesLibrary

  Path: shell:PicturesLibrary
  SHParseDisplayName succeeded (SFGAO = 0xB080007D)
    SFGAO_FILESYSANCESTOR
    SFGAO_FOLDER
#>

Set-StrictMode -Version Latest

#region 1. Define helper to load C# definitions once
function Add-ShellApiTypes {
    <#
    .SYNOPSIS
      Loads a dynamic C# assembly that defines ShellParse.ShellInterop if not already loaded.

    .DESCRIPTION
      Checks if the type [ShellParse.ShellInterop] exists in the current AppDomain.
      If not, calls Add-Type to compile the C# code for SHParseDisplayName usage.
    #>

    $existingInterop = [AppDomain]::CurrentDomain.GetAssemblies() |
        ForEach-Object {
            $_.GetType("ShellParse.ShellInterop")
        } | Where-Object { $_ -ne $null }

    if (-not $existingInterop) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace ShellParse
{
    [Flags]
    public enum SFGAO : uint
    {
        SFGAO_FILESYSTEM      = 0x40000000, // Indicates a real file-system item
        SFGAO_FILESYSANCESTOR = 0x10000000, // Can contain file-system items
        SFGAO_FOLDER          = 0x20000000  // It's a folder (container)
        // Other flags exist, but these three are the primary ones for demonstration
    }

    public static class ShellInterop
    {
        // SHParseDisplayName helps parse a string into a PIDL and can return SFGAO attributes
        [DllImport("shell32.dll", CharSet=CharSet.Unicode, SetLastError=false)]
        public static extern int SHParseDisplayName(
            string pszName,
            IntPtr pbc,
            out IntPtr ppidl,
            uint sfgaoIn,
            out uint psfgaoOut
        );

        // CoTaskMemFree frees the PIDL after we're done
        [DllImport("ole32.dll")]
        public static extern void CoTaskMemFree(IntPtr pv);
    }
}
"@ -ErrorAction Stop
    }
    else {
        Write-Host "ShellParse.ShellInterop is already loaded in this session."
    }
}
#endregion

#region 2. Ensure the Shell API types are loaded
Add-ShellApiTypes
#endregion

#region 3. Define a function that uses SHParseDisplayName
function Get-ParsedSFGAO {
    <#
    .SYNOPSIS
      Parses a path with SHParseDisplayName and outputs SFGAO flags.

    .PARAMETER Path
      The path to parse (e.g., '\\wsl$\Ubuntu', 'C:\Windows', 'shell:PicturesLibrary').

    .DESCRIPTION
      Calls SHParseDisplayName to convert the specified path to a PIDL, retrieves SFGAO flags,
      and prints which flags are set. If the Shell cannot parse the path, an HRESULT error is shown.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0)]
        [string]$Path
    )

    # 4294967295 is 0xFFFFFFFF as uint32 (full mask for SFGAO attributes)
    [uint32]$sfgaoIn  = 4294967295
    [uint32]$sfgaoOut = 0

    # Will store the parsed PIDL
    $pidl = [IntPtr]::Zero

    # Call SHParseDisplayName
    $hr = [ShellParse.ShellInterop]::SHParseDisplayName($Path, [IntPtr]::Zero, [ref]$pidl, $sfgaoIn, [ref]$sfgaoOut)

    Write-Host "`nPath: $Path"

    if ($hr -ne 0) {
        Write-Host ("SHParseDisplayName failed (HRESULT = 0x{0:X})" -f $hr)
        return
    }

    Write-Host ("SHParseDisplayName succeeded (SFGAO = 0x{0:X8})" -f $sfgaoOut)

    # Decode some interesting flags
    if ($sfgaoOut -band 0x40000000) { Write-Host "  SFGAO_FILESYSTEM" }
    if ($sfgaoOut -band 0x10000000) { Write-Host "  SFGAO_FILESYSANCESTOR" }
    if ($sfgaoOut -band 0x20000000) { Write-Host "  SFGAO_FOLDER" }

    # Free the PIDL
    if ($pidl -ne [IntPtr]::Zero) {
        [ShellParse.ShellInterop]::CoTaskMemFree($pidl)
    }
}
#endregion

#region 4. Prompt the user for a path, then run the check
$path = Read-Host -Prompt "Enter a path to check (e.g. '\\wsl$\' or 'C:\Windows' or 'shell:PicturesLibrary')"

Get-ParsedSFGAO -Path $path
#endregion
