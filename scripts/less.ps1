param (
	[string] $file
)

if ($PSBoundParameters.ContainsKey('file')) {
  Get-Content $file | more
} else {
   Write-Output "What file to tail?"
}
