<#
.SYNOPSIS
    Removes files matching a pattern that are older than a specified date.

.PARAMETER Path
    Root directory to search recursively. Defaults to current directory.

.PARAMETER Pattern
    File name pattern to match (e.g. "*.log", "temp_*"). Required.

.PARAMETER DaysOld
    Remove files older than this many days. Defaults to 30.

.PARAMETER CutoffDate
    Explicit cutoff date. If provided, overrides DaysOld.

.PARAMETER WhatIf
    Show what would be deleted without actually deleting.

.EXAMPLE
    .\Remove-OldFiles.ps1 -Pattern "*.log"
    Deletes all .log files older than 30 days under the current directory.

.EXAMPLE
    .\Remove-OldFiles.ps1 -Pattern "*.tmp" -DaysOld 7 -Path "D:\Logs"
    Deletes .tmp files older than 7 days under D:\Logs.

.EXAMPLE
    .\Remove-OldFiles.ps1 -Pattern "*.bak" -CutoffDate "2025-01-01" -WhatIf
    Preview which .bak files would be deleted (older than Jan 1 2025).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Pattern,

    [Parameter(Mandatory = $false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [int]$DaysOld = 30,

    [Parameter(Mandatory = $false)]
    [datetime]$CutoffDate,

    [Parameter(Mandatory = $false)]
    [Alias('l')]
    [switch]$List
)

if (-not (Test-Path $Path)) {
    Write-Error "Path not found: $Path"
    exit 1
}

if ($Pattern -in @('*', '*.*')) {
    Write-Warning "Pattern '$Pattern' will match ALL files under $Path"
    $confirm = Read-Host "Are you sure you want to delete all matching files? (yes/no)"
    if ($confirm -ne 'yes') {
        Write-Host "Aborted."
        exit 0
    }
}

$cutoff = if ($PSBoundParameters.ContainsKey('CutoffDate')) {
    $CutoffDate
} else {
    (Get-Date).AddDays(-$DaysOld)
}

Write-Host "Scanning : $Path"
Write-Host "Pattern  : $Pattern"
Write-Host "Cutoff   : $($cutoff.ToString('yyyy-MM-dd HH:mm:ss')) (files last written before this will be removed)"
Write-Host ""

$files = Get-ChildItem -Path $Path -Filter $Pattern -Recurse -File -ErrorAction SilentlyContinue |
         Where-Object { $_.LastWriteTime -lt $cutoff }

if ($files.Count -eq 0) {
    Write-Host "No files matched."
    exit 0
}

$totalSize = ($files | Measure-Object -Property Length -Sum).Sum
Write-Host ("Found {0} file(s) totalling {1:N1} MB" -f $files.Count, ($totalSize / 1MB))
Write-Host ""

$deleted = 0
$errors  = 0

foreach ($file in $files) {
    if ($PSCmdlet.ShouldProcess($file.FullName, "Remove")) {
        try {
            Remove-Item -Path $file.FullName -Force
            if ($List) { Write-Host "Deleted: $($file.FullName)  [$($file.LastWriteTime.ToString('yyyy-MM-dd'))]" }
            $deleted++
        } catch {
            Write-Warning "Failed to delete $($file.FullName): $_"
            $errors++
        }
    }
}

Write-Host ""
Write-Host "Done. Deleted: $deleted  Errors: $errors"
