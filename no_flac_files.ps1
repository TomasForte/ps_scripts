$ErrorActionPreference = "Stop"

Get-ChildItem -Recurse -File |
Where-Object {$_.Extension -match "\.(mp3|flac|wav|aac|ogg|m4a|opus|alac|ape|tak)$" }| 
ForEach-Object {
    if ($_.Extension -eq ".flac"){
        $metadata = ffprobe -i $_.FullName -show_entries format_tags=album,title -v  quiet -of csv=p=0



        $album, $title = $metadata -split ","
        if ([string]::isNullOrEmpty($album) -or [string]::isNullOrEmpty($title)) {
            $_
        }
    } else {
        $_
    }
} |
 Select-Object FullName, Name, Extension