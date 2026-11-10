param (
	[string] $file,
	[int] $lines=10
)

if ($PSBoundParameters.ContainsKey('file')) {
  Get-Content -Path $file -Tail $lines -Wait
} else {
   Write-Output "What file to tail?"
}
