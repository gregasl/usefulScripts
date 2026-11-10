Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine | Format-Table -AutoSize -Wrap 
