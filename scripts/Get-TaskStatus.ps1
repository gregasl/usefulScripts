<#
.SYNOPSIS
    Lists Windows Task Scheduler tasks with last run time and pass/fail status.

.DESCRIPTION
    Reads scheduled tasks via Get-ScheduledTask and joins their runtime info from
    Get-ScheduledTaskInfo (last run time, last result code, next run time, state).
    The numeric LastTaskResult is decoded into a human-readable Status, and a
    Failed flag marks any task whose last run ended in a genuine error (as opposed
    to informational codes like "never run" or "currently running").

.PARAMETER TaskPath
    Optional folder filter, e.g. "\MyJobs\" or "\Microsoft\*". Default lists all.

.PARAMETER FailedOnly
    Show only tasks whose last run failed.

.PARAMETER IncludeBuiltIn
    Include built-in Windows/Microsoft tasks (those under the \Microsoft\ path).
    By default these are excluded so only user/third-party tasks are shown.

.PARAMETER ComputerName
    Optional remote machine name to query instead of the local box. Uses a
    CIM session (WS-Man / WinRM must be enabled on the target). Multiple names
    are allowed; results are tagged with a ComputerName column.

.PARAMETER Credential
    Optional credential for the remote CIM session. If omitted, the current
    user's Windows identity is used.

.PARAMETER CsvPath
    Optional path to also export the results as CSV.

.EXAMPLE
    .\Get-TaskStatus.ps1

.EXAMPLE
    .\Get-TaskStatus.ps1 -FailedOnly

.EXAMPLE
    .\Get-TaskStatus.ps1 -TaskPath "\MyJobs\" -CsvPath .\task-status.csv

.EXAMPLE
    .\Get-TaskStatus.ps1 -IncludeBuiltIn

.EXAMPLE
    .\Get-TaskStatus.ps1 -ComputerName ASLAPP01 -FailedOnly

.EXAMPLE
    .\Get-TaskStatus.ps1 -ComputerName ASLAPP01 -Credential (Get-Credential)
#>

[CmdletBinding()]
param(
    [string]$TaskPath = "\*",
    [switch]$FailedOnly,
    [switch]$IncludeBuiltIn,
    [string[]]$ComputerName,
    [System.Management.Automation.PSCredential]$Credential,
    [string]$CsvPath
)

# Informational LastTaskResult codes that are NOT failures.
# Anything else non-zero is treated as a failed run.
# Keyed by [long] so codes above Int32 range (e.g. 0x80070002) do not overflow.
$infoCodes = @{
    ([long]0x0)        = "Success"
    ([long]0x41300)    = "Ready (not yet run)"
    ([long]0x41301)    = "Currently running"
    ([long]0x41302)    = "Disabled"
    ([long]0x41303)    = "Not yet run"
    ([long]0x41304)    = "No more runs scheduled"
    ([long]0x41306)    = "Terminated by user"
    ([long]0x00041325) = "Queued"
}

function Resolve-Status {
    param([long]$Code)
    if ($infoCodes.ContainsKey($Code)) { return $infoCodes[$Code] }
    # Non-zero, non-informational => failure. Show as 0x-hex for lookup.
    return ("Failed (0x{0:X8})" -f ([uint32]$Code))
}

function Test-Failed {
    param([long]$Code)
    return -not $infoCodes.ContainsKey($Code)
}

# A few task-scheduler / COM HRESULTs that Win32Exception does not describe well.
# Keyed by 8-digit uppercase hex string to avoid PowerShell parsing high-bit-set
# hex literals (0x8xxxxxxx) as negative Int32.
$knownHResults = @{
    "80040154" = "Class not registered (REGDB_E_CLASSNOTREG)"
    "80131509" = "Invalid operation (.NET)"
    "8004130F" = "No account information / credentials for the task"
    "8004131F" = "An instance of this task is already running"
    "80041321" = "Task image is corrupt or has been tampered with"
    "FFFFFFF8" = "Application returned exit code -8"
}

function Resolve-Message {
    # Decode a LastTaskResult code into a human-readable error message.
    param([long]$Code)
    if ($Code -eq 0) { return "Success" }
    $u = [uint32]$Code
    if ($infoCodes.ContainsKey($Code)) { return $infoCodes[$Code] }
    $hex = "{0:X8}" -f $u
    if ($knownHResults.ContainsKey($hex)) { return $knownHResults[$hex] }
    try {
        # Win32-facility HRESULT (0x8007xxxx): high word is 0x8007, low word is
        # the underlying Win32 error code. Use a shift to avoid PowerShell
        # parsing 0xFFFF0000-style masks as negative Int32.
        if (($u -shr 16) -eq 0x8007) {
            $w = [int]($u -band 0xFFFF)
            return ([System.ComponentModel.Win32Exception]$w).Message
        }
        # Bare Win32 error code (fits in Int32).
        if ($u -le [int]::MaxValue) {
            return ([System.ComponentModel.Win32Exception][int]$u).Message
        }
    } catch { }
    return ("Unmapped HRESULT 0x{0:X8}" -f $u)
}

# Build the list of CIM sessions to query. No -ComputerName => local machine
# (a $null session), otherwise one session per remote host.
$sessions = @()
if ($ComputerName) {
    foreach ($cn in $ComputerName) {
        try {
            $opt = New-CimSessionOption -Protocol Wsman
            if ($Credential) {
                $sessions += New-CimSession -ComputerName $cn -Credential $Credential -SessionOption $opt -ErrorAction Stop
            } else {
                $sessions += New-CimSession -ComputerName $cn -SessionOption $opt -ErrorAction Stop
            }
        } catch {
            Write-Warning ("Could not connect to {0}: {1}" -f $cn, $_.Exception.Message)
        }
    }
    if (-not $sessions) { Write-Warning "No remote sessions established."; return }
} else {
    $sessions = @($null)
}

$results = foreach ($session in $sessions) {
    # Splat the CimSession only when remote; local calls take no -CimSession.
    $common = @{ TaskPath = $TaskPath; ErrorAction = "SilentlyContinue" }
    if ($session) { $common["CimSession"] = $session }
    $hostLabel = if ($session) { $session.ComputerName } else { $env:COMPUTERNAME }

    Get-ScheduledTask @common | ForEach-Object {
        $task = $_
        $infoArgs = @{ ErrorAction = "SilentlyContinue" }
        if ($session) { $infoArgs["CimSession"] = $session }
        $info = $task | Get-ScheduledTaskInfo @infoArgs
        if ($null -eq $info) { return }

        $code = [long]$info.LastTaskResult
        [PSCustomObject]@{
            ComputerName = $hostLabel
            TaskName     = $task.TaskName
            TaskPath     = $task.TaskPath
            State        = $task.State
            LastRunTime  = $info.LastRunTime
            Status       = Resolve-Status -Code $code
            Message      = Resolve-Message -Code $code
            ResultCode   = ("0x{0:X8}" -f ([uint32]$code))
            Failed       = Test-Failed -Code $code
            NextRunTime  = $info.NextRunTime
        }
    }
}

# Drop built-in Windows/Microsoft tasks unless explicitly requested.
if (-not $IncludeBuiltIn) {
    $results = $results | Where-Object { $_.TaskPath -notlike '\Microsoft\*' }
}

if ($FailedOnly) {
    $results = $results | Where-Object { $_.Failed }
}

$results = $results | Sort-Object Failed -Descending | Sort-Object LastRunTime -Descending

$results | Format-Table ComputerName, TaskName, State, LastRunTime, Status, Message -AutoSize -Wrap

$failCount = ($results | Where-Object { $_.Failed } | Measure-Object).Count
Write-Output ""
Write-Output ("Total tasks listed: {0}  |  Failed: {1}" -f ($results | Measure-Object).Count, $failCount)

# Clean up any remote sessions we opened.
if ($ComputerName -and $sessions) {
    $sessions | Where-Object { $_ } | Remove-CimSession -ErrorAction SilentlyContinue
}

if ($CsvPath) {
    $results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    Write-Output ("CSV written to: {0}" -f (Resolve-Path $CsvPath))
}
