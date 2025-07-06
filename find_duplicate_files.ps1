 $hashTable = @{}

 Get-ChildItem  -Recurse -File | ForEach-Object {
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

 # Display duplicates
 $hashTable.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 } | ForEach-Object {
    Write-Host "`nDuplicate files:"
     $_.Value | ForEach-Object { Write-Host "  $_" }
 }