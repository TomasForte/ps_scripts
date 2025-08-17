$ErrorActionPreference = "Stop"

$matches = Get-ChildItem -Recurse -File |
Where-Object {$_.Extension -match "\.(mp3|flac|wav|aac|ogg|m4a|opus|alac|ape|tak)$" }| 
ForEach-Object {
    if ($_.Extension -eq ".flac"){
        $metadata = ffprobe -i $_.FullName -show_entries format_tags=artist,album,title -v quiet -of csv=p=0



        $artist, $title, $album = $metadata -split ","
        if ([string]::isNullOrEmpty($artist) -or [string]::isNullOrEmpty($title) -or [string]::isNullOrEmpty($album )) {
            $_
        }
    } else {
        $_
    }
} |
 Select-Object FullName, Name, Extension

$matches

$matches.Count