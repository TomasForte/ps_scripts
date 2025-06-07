param (
    [string]$URL,
    [switch]$Verbose
)

#remove symbols that would break path
function CleanPathBreakingSymbols {
    param ($inputString)

    $inputString = $inputString -replace "[<>:?*|\\/]", ""
    #Inside regex \ can also be used as escape character but i kept the ` to keep it simple
    $inputString = $inputString -replace "[[]", "``[]"
    return $inputString -replace "[`]]", "``]]"

}

#find extension of the image
function Get-ImageExtension {
    param ([string]$ContentType)

    switch ($ContentType) {
        "image/jpeg" { return ".jpg" }
        "image/png"  { return ".png" }
        "image/webp" { return ".webp" }
        "image/gif"  { return ".gif" }
        "image/tiff" { return ".tiff" }
        default      { return ".unknown" } 
}
}

#============================WARNING========================
#https://exiftool.org/forum/index.php?topic=6721.0
#I can't find a way to make exiftool accepet UTF-8 character like ☆ in path  directly
#I changed the powershell enconding input and output, also added -charset filename=UTF8 to exiftool and nothing works
#The only solution i Found was storing the Path in a txt  file with UTF8 encoding and then load the path from there
# I think that exiftool might actually get the path as UTF16 which is the way windows stored strings
#=============================TODO=========================
# to fix the problem above
#I could creata "metadata" using ADS to file stream (only works on windows, then again this is a powershell script LOL)
#Set-Content -Path xxx -Stream yyy or Set-Content -Path xxx:yyy



$ErrorActionPreference = "Stop"
$page = Invoke-WebRequest -Uri $URL 
# ParseHtml only works with powershell 5 or bellow and relly on internet explorer-based parsing
# powershell 5 is still the default on windows 11 so it should still work when i update my system
$table = $page.ParsedHtml.GetElementsByTagName("table")[0]
$tableBody = $table.getElementsByTagName("tbody")
$path = "C:\Users\Utilizador\Desktop\Badges2"
Get-ChildItem -Path $Path -File -Recurse | Select-Object -ExpandProperty FullName | Out-File "filenames.txt" -Encoding UTF8
$sourceInFolder = exiftool -@ .\filenames.txt -q -p '$Source' 

try {
    $number  = 0

    ForEach ($tbody in $tableBody){
        #remove rows where the image is already downloaded
        $validRows = $tbody.rows | Where-Object {
            $cellImage = $_.cells[4].GetElementsByTagName("a")[0].href
            $sourceInFolder -notcontains $cellImage
        }
        ForEach ($row in $validRows)
        {
            $number++
            $cellCategory = CleanPathBreakingSymbols $row.cells[0].innerText
            $cellChallenge = CleanPathBreakingSymbols $row.cells[1].innerText
            $cellDifficulty = CleanPathBreakingSymbols $row.cells[2].innerText
            $cellRun = CleanPathBreakingSymbols $row.cells[3].innerText
            $cellImage = $row.cells[4].GetElementsByTagName("a")[0].href
            $imageExtension = $cellImage.Split(".")[-1]
            $imageExtension = $imageExtension.Split("/")[0] #some url are weird like http://i.imgur.com/xxxxx.png/yyyyy
            Write-Host $number
            if ($CellRun -eq "0")
            {
                $status = "Participant"
            }
            else
            {
                $status = "Completed"
            }
            $dirPath="$path\$cellCategory\$cellChallenge"
            
            #---check if there dir for to store the image create it if needed
            if (!(Test-Path $dirPath))
            {
                try{
                    New-Item -ItemType Directory -Path $dirPath
                } catch {
                    Write-Host "folder couldn't be created"
                    Write-Host "Path $dirPath"
                    Write-Host "challenge $cellChallenge"
                    Write-Host ("Error: $($_.Exception.Message)")
                    exit 1

                }
            }
            #Load Image from url
            try{
                $Image = Invoke-WebRequest -Uri $cellImage -UseBasicParsing
                
                $baseName = "$cellChallenge $status x$cellRun"
                $numberFiles = (Get-ChildItem -Path $dirPath -File -Filter "*$baseName*").Count
                
                #the extension in the image url might not be the correct like https://i.imgur.com/xxxxxx.png 
                #can actually be a gif so i need to check the codec of the image and saved in a correct file extension
                $extension = Get-ImageExtension $Image.Headers["Content-Type"]
                $outputFile = "$dirPath\$($baseName)_$(($numberFiles+1).ToString("D3"))$extension"
                $Image.Content | Set-Content -Path $outputFile -Encoding Byte
                Write-Host "$outputFile"
            } catch {
                Write-host ("$cellChallenge image could not be downloaded")
                Write-Host ("Path - $outputFile")
                Write-Host ("Error: $($_.Exception.Message)")
                exit 1
            }

            try{
                $outputFile | Out-File "param.txt" -Encoding utf8
                exiftool -xmp:Source=$cellImage -@ "param.txt"

                #exiftool sometimes exits without terminal error so i need to throw error based one the exitcode
                if ($LASTEXITCODE -ne 0) {
                    throw "ExifTool failed to process file"
                }
            } catch {
                Write-Host "could't add source to image metada"
                Write-Host "path: $dirPath File $baseName"
                Write-Host ("Error: $($_.Exception.Message)")
                Remove-Item -Path "$($outputFile)"
                exit 1
            }

            try{
                Remove-Item -Path "$($outputFile)_original"
            } catch {
                Write-Host "could delete backup file created by exiftool"
                Write-Host ("Error: $($_.Exception.Message)")
                exit 1
            }   
        }            
    }
} catch {
    Write-Host ("Error: $($_.Exception.Message)")
}


