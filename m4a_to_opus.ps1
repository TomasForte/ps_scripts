$ErrorActionPreference = "Stop"
Get-ChildItem -Filter "*m4a" |
ForEach-Object{
    $NumberAudioStreams =  ffprobe -i "$($_.FullName)" `
                        -v error `
                        -select_streams a`
                        -show_entries stream=index `
                        -of compact=p=0:nk=1 | Measure-Object

    if ($NumberAudioStreams -eq 0){
        Write-Host $_.FULLNAME
        Write-Host "$($_.Name) has no audio stream"
    }
    elseif ($NumberAudioStreams -gt 1) {
        Write-Host $_.FULLNAME
        Write-Host "$($_.Name) has more than 1 audio stream"
    }
    else {
        $codec = ffprobe -i "$($_.FullName)" `
                        -v error `
                        -select_streams a`
                        -show_entries stream=codec_name `
                        -of compact=p=0:nk=1

        if ($codec -ep "opus"){
            $outputFile = "$($_.DirectoryName)\$($_.BaseName).opus"
            ffmpeg -i "$($_.FullName)" -c:a:0 copy $outputFile
            if (Test-Path $outputFile) {
                Remove-Item -Force "$($_.FullName)"
            }
        }
                        
    }
} 
