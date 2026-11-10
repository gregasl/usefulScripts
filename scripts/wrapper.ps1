# wrapper.ps1 - forwards all positional and named parameters to a sub-script
param(
    [Parameter(Position = 0)]
    [string]$SubScript,

    [Parameter(ValueFromRemainingArguments)]
    [object[]]$PassThrough
)

if (-not $SubScript) {
    Write-Error "Usage: wrapper.ps1 <sub-script> [args...]"
    exit 1
}

if (-not (Test-Path $SubScript)) {
    Write-Error "Sub-script not found: $SubScript"
    exit 1
}

& $SubScript @PassThrough
