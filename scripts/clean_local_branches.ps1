git fetch -p; git branch -vv | Where-Object { $_ -match 'gone\]' } | ForEach-Object { git branch -D $_.Trim().Split()[0] }

