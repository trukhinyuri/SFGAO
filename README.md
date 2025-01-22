# check.ps1

A PowerShell script to analyze how Windows **Shell** interprets various paths (local directories, `\\wsl$`, `shell:` URIs, etc.) by retrieving **Shell attributes** (`SFGAO_*`) via the Win32 API. It helps explain why some locations appear in folder picker dialogs (`FOS_PICKFOLDERS`) but not in regular file open/save dialogs.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Why `SFGAO_FILESYSTEM` Matters](#why-sfgao_filesystem-matters)
- [Requirements](#requirements)
- [Usage](#usage)

---

## Overview

In Windows, the **Shell** can treat different paths in different ways—some are recognized as “real” file system objects, others as “virtual” or “namespace” extensions. This **check.ps1** script uses low-level Shell APIs (in particular, `SHParseDisplayName`) to parse a user-supplied path and report back critical **SFGAO** flags.

These flags determine whether a path is considered:
- A *true* filesystem object (`SFGAO_FILESYSTEM`),
- A file system *ancestor* (`SFGAO_FILESYSANCESTOR`),
- A *folder-like* container (`SFGAO_FOLDER`),
- Or something else entirely.

**Key Insight**:  
- A location **without** `SFGAO_FILESYSTEM` but **with** `SFGAO_FILESYSANCESTOR` often **does appear** in a **folder picker** dialog but is **hidden** from classic file open/save dialogs, since the latter may require a full Win32 filesystem path.

---

## Features

- **Retrieves Shell attributes** (`SFGAO_*`) for a specified path using `SHParseDisplayName`.
- **Highlights** the difference between true filesystem objects (`SFGAO_FILESYSTEM`) and “virtual” or “namespace-only” folders (`SFGAO_FILESYSANCESTOR`).
- **Explains** why certain paths (e.g., `\\wsl$`, libraries like `shell:PicturesLibrary`, or network shares) behave differently in Windows UI.
- **Interactive**: prompts for a path, then shows the parsed attributes.

---

## How It Works

1. **User inputs a path** in PowerShell (e.g., `\\wsl$\Ubuntu`, `C:\Windows`, `shell:PicturesLibrary`, etc.).
2. The script **calls** `SHParseDisplayName` to parse the path into a PIDL (Pointer to an Item ID List).
3. Windows Shell **returns** flags (`SFGAO_*`) describing the item (is it a real FS object? is it an ancestor? a folder?).
4. The script **displays** these flags, clarifying how the Shell classifies that location.

---

## Why `SFGAO_FILESYSTEM` Matters

- **`SFGAO_FILESYSTEM`** indicates the path is part of the real file system in the Shell’s view.
- **`SFGAO_FILESYSANCESTOR`** means the path can **lead to** real file-system objects but isn’t itself a classic Win32 filesystem path.
- **`FOS_PICKFOLDERS`** (the folder picker dialog flag) often **shows** items with `SFGAO_FILESYSANCESTOR`, even without `SFGAO_FILESYSTEM`.
  - This is why WSL (`\\wsl$`) or `shell:PicturesLibrary` might appear in folder dialogs but remain hidden in a standard file open/save dialog.

---

## Requirements

- **Windows 10/11** with standard Shell components  
  (On Windows Server Core or minimal installations, the necessary Shell functionality may be absent or limited.)
- **PowerShell 5.1+** or later.
- Sufficient **permissions** to run scripts (`Set-ExecutionPolicy`) or a signed script.

---

## Usage

1. **Clone** or download this repository.
2. Open a **PowerShell** session.
3. Navigate to the folder containing `check.ps1`.
4. **Run** the script:
   ```powershell
   .\check.ps1
