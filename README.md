# usefulScripts

Personal PowerShell helpers and profiles.

- `scripts/` — command-line helpers (keep this folder on `PATH`; mirrors `U:\scripts`).
- `profiles/WindowsPowerShell/` — copy to `$HOME\Documents\WindowsPowerShell\` (PowerShell 5.1).
- `profiles/PowerShell7/` — copy to `$HOME\Documents\PowerShell\` (PowerShell 7).

Restore profiles on a new machine:

```powershell
New-Item -ItemType Directory -Force "$HOME\Documents\WindowsPowerShell","$HOME\Documents\PowerShell" | Out-Null
Copy-Item .\profiles\WindowsPowerShell\* "$HOME\Documents\WindowsPowerShell\"
Copy-Item .\profiles\PowerShell7\* "$HOME\Documents\PowerShell\"
```
