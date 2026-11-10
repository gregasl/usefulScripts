<#
.SYNOPSIS
    Lists users who have a file open on a Windows file server.

.DESCRIPTION
    Queries open SMB file handles and reports which users are holding them.
    Works in two modes:
      - Local: query the current machine (must be the file server hosting the share)
      - Remote: query a remote file server via -ComputerName (requires admin rights on that server)

    Matching is done by substring against the SMB Path. You can pass a full UNC path,
    a local server path, or just a filename fragment.

.PARAMETER Path
    Full path or substring to match against open files. Case-insensitive.
    Examples:
      "C:\Shares\Reports\Q1.xlsx"
      "Q1.xlsx"
      "\\aslfile01\aslcap\IT\Software\some_workbook.xlsx"

.PARAMETER ComputerName
    The file server hosting the share. Defaults to the local machine.
    For \\aslfile01\... shares, pass -ComputerName aslfile01.

.EXAMPLE
    .\Get-FileLockOwners.ps1 -Path "budget.xlsx"

.EXAMPLE
    .\Get-FileLockOwners.ps1 -Path "Quant Analysis\model.xlsm" -ComputerName aslfile01

.NOTES
    Requires admin rights on the target file server.
    Get-SmbOpenFile is available on Windows Server 2012+ and Windows 8+.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Position = 1)]
    [string]$ComputerName = $env:COMPUTERNAME
)

Write-Host "Querying open files on $ComputerName matching: $Path" -ForegroundColor Cyan

try {
    if ($ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost' -or $ComputerName -eq '.') {
        $openFiles = Get-SmbOpenFile -ErrorAction Stop
    }
    else {
        $openFiles = Get-SmbOpenFile -CimSession $ComputerName -ErrorAction Stop
    }
}
catch {
    Write-Error "Failed to query open files on '$ComputerName'. $($_.Exception.Message)"
    Write-Host "Tip: you must run as an admin on the file server, and the Server service must be running." -ForegroundColor Yellow
    exit 1
}

$matches = $openFiles | Where-Object { $_.Path -like "*$Path*" -or $_.ShareRelativePath -like "*$Path*" }

if (-not $matches) {
    Write-Host "No open handles found matching '$Path' on $ComputerName." -ForegroundColor Yellow
    exit 0
}

$report = $matches | Select-Object `
    @{N = 'User';         E = { $_.ClientUserName } }, `
    @{N = 'ClientHost';   E = { $_.ClientComputerName } }, `
    @{N = 'File';         E = { $_.Path } }, `
    @{N = 'Share';        E = { $_.ShareRelativePath } }, `
    @{N = 'SessionId';    E = { $_.SessionId } }, `
    @{N = 'FileId';       E = { $_.FileId } }

$report | Sort-Object User, File | Format-Table -AutoSize -Wrap

$uniqueUsers = $report | Select-Object -ExpandProperty User -Unique
Write-Host ""
Write-Host "Total handles: $($report.Count)" -ForegroundColor Green
Write-Host "Unique users : $($uniqueUsers.Count) -- $($uniqueUsers -join ', ')" -ForegroundColor Green
