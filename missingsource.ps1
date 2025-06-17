
Get-ChildItem -File -Recurse | Select-Object -ExpandProperty FullName | Out-File "filename.txt" -Encoding UTF8

$metadata = exiftool -charset filename=utf8 -q -@ "filename.txt" -if 'not defined $Source' -s3 -p '${filepath;s/\//\\/g}'