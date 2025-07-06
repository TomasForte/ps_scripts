 param (
    [string]$Path = (Get-Location).Path,
    [string]$PathExcluded
)
 #NOTE this is useless if path  parameters is provided because it dedault to fullpath
 $Path = Resolve-Path $Path
 

 if ($PathExcluded -ne $null)
 {
    $pathExcluded = (Resolve-Path $PathExcluded).Path
    $pathExcluded = $pathExcluded.TrimEnd('\')
 }
 
 $hashTable = @{}

 Get-ChildItem -LiteralPath $Path -Directory | WHERE-Object { ($_.FullName -ne $PathExcluded)} | 

    ForEach-Object {
         Get-ChildItem -LiteralPath $_.FullName -Recurse -File |
         ForEach-Object{
            $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
            if ($null -ne $hash.Hash) {
                if ($hashTable.ContainsKey($hash.Hash)) {
                    $hashTable[$hash.Hash] += ,$_.FullName
                } else {
                    $hashTable[$hash.Hash] = @($_.FullName)
                }
            } else {
                $hash
            }
         }

}

 # Display duplicates
 $hashTable.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | ForEach-Object {
    Write-Host "`nDuplicate files:"
     $_.Value | ForEach-Object { Write-Host "  $_" }
 }