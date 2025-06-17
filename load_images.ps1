param (
    [string]$URL,
    [switch]$Verbose
)

#remove symbols that would break path
function CleanPathBreakingSymbols {
    param ($inputString)

    $inputString = $inputString -replace "[<>:?*|\\/]", ""
    #Inside regex \ can also be used as escape character but i kept the ` to keep it simple
    #$inputString = $inputString -replace "[[]", "``["
    return $inputString 

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

$path = "C:\Users\Utilizador\Desktop\Badges2"
$path = $path -replace '\.+$', ''
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Loading source from images in disk"
Get-ChildItem -Path $path -File -Recurse | Select-Object -ExpandProperty FullName | Out-File "filenames.txt" -Encoding UTF8
$sourceInFolder = exiftool -@ .\filenames.txt -q -p '$Source'

Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Requesting site"
$page = Invoke-WebRequest -Uri $URL 
# ParseHtml only works with powershell 5 or bellow and relly on internet explorer-based parsing
# powershell 5 is still the default on windows 11 so it should still work when i update my system
$table = $page.ParsedHtml.GetElementsByTagName("table")[0]
$tableBody = $table.getElementsByTagName("tbody")



$jobs = @()
$failedJobs = @()
$batchsize = 10


Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Starting process"
ForEach ($tbody in $tableBody){
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Finding rows with new images"
    #remove rows where the image is already downloaded
    $validRows = $tbody.rows | Where-Object {
        $cellImage = $_.cells[4].GetElementsByTagName("a")[0].href
        $sourceInFolder -notcontains $cellImage
    }

    if ($validRows.Count -eq 0) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') No new images found!"
        continue
    }



    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Starting Downloads"
    Write-Host "$($validRows.Count) images to download"
    Start-Sleep 20
    ForEach ($row in $validRows){
        if($jobs.Count -ge $batchsize){
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Waiting for batch jobs to complete..."


            
            Wait-Job -Job $jobs | Out-Null
            Get-Job
            $failedJobs += Get-Job | Where-Object { $_.State -eq "Failed" }
            
            #Get-Job | Where-Object { $_.State -in @( "Completed") } | Receive-job
            Get-Job | Where-Object { $_.State -in @("Failed", "Completed") } | Remove-Job
            $jobs = @($jobs | Where-Object { $_.State -notin @("Completed", "Failed") })

            Write-host ""
            #$failedJobs | Receive-Job
            

        }
            
        Write-Host "$($row.cells[4].GetElementsByTagName("a")[0].href)"
        $jobs += Start-ThreadJob -ThrottleLimit 3 -ScriptBlock {
            param ($row, $path, $CleanPathBreakingSymbolsFunction, $GetImageExtensionFunction, $jobId)
            $success = $false
            $cellCategory = & $CleanPathBreakingSymbolsFunction $row.cells[0].innerText
            $cellChallenge = & $CleanPathBreakingSymbolsFunction $row.cells[1].innerText
            $cellDifficulty = & $CleanPathBreakingSymbolsFunction $row.cells[2].innerText
            $cellRun = & $CleanPathBreakingSymbolsFunction $row.cells[3].innerText
            $cellImage = $row.cells[4].GetElementsByTagName("a")[0].href
            $creator = & $CleanPathBreakingSymbolsFunction $row.cells[5].innerText
            $imageExtension = $cellImage.Split(".")[-1]
            $imageExtension = $imageExtension.Split("/")[0] #some url are weird like http://i.imgur.com/xxxxx.png/yyyyy
            

            #Removing dots at the end of directory
            #windows allows creating of folder with dots be removes them internaly
            #the means i can create a file with a dot at the end of dir name
            #but when i use the same path to remove the item windows  doesn't find it because it removed the dots
            $cellCategory = $cellCategory -replace '\.+$', ''
            $cellChallenge = $cellChallenge -replace '\.+$', ''
            
            $dirPath="$path\$cellCategory\$cellChallenge"
            
            #---check if there dir for to store the image create it if needed
            if (!(Test-Path -LiteralPath $dirPath))
            {
                try{
                    New-Item -ItemType Directory -Path $dirPath
                } catch {
                    Write-Host "folder couldn't be created"
                    Write-Host "Path $dirPath"
                    Write-Host "challenge $cellChallenge"
                    throw ("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Error creating folder: $($_.Exception.Message)")
                }
            }
            #Load Image from url

            try{
                $Image = Invoke-WebRequest -Uri $cellImage -UseBasicParsing               
                $baseName = "$($cellChallenge)_x$cellRun"
                $numberFiles = (Get-ChildItem -LiteralPath $dirPath -File -Filter "*$baseName*").Count
                #the extension in the image url might not be the correct like https://i.imgur.com/xxxxxx.png 
                #can actually be a gif so i need to check the codec of the image and saved in a correct file extension
                $extension = & $GetImageExtensionFunction $Image.Headers["Content-Type"]
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmssfff"
                #$outputFile = "$dirPath\$($baseName)_$(($numberFiles+1).ToString("D3"))$extension"
                $outputFile = "$dirPath\$($baseName)_$($timestamp)-$($jobId)$extension"
                [System.IO.File]::WriteAllBytes($outputFile, $Image.Content)
                #$Image.Content | Set-Content -LiteralPath $outputFile -Encoding Byte
                $Image = $null # Force release of image (no variable is referencing)
            } catch {
                    Write-host ("$cellChallenge image could not be downloaded")
                    Write-Host ("Path - $outputFile")
                    Write-Host $cellImage
                    throw ("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Error downloading image: $($_.Exception.Message)")               
            }


            try{
                $file = "$jobId.txt"
                $outputFile | Out-File -FilePath $file -Encoding utf8
                exiftool -xmp:Source=$cellImage -@ $file -q 
                Remove-item -LiteralPath $file
                
                #exiftool sometimes exits without terminal error so i need to throw error based one the exitcode
                if ($LASTEXITCODE -ne 0) {
                    throw "ExifTool failed to process file"
                }
            } catch {
                Write-Host "could't add source to image metada"
                Write-Host "path: $dirPath"
                Write-Host "File $baseName"
                Write-host "job: $jobId"
                Remove-Item -LiteralPath "$($outputFile)"
                throw ("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Error adding metadata to file: $($_.Exception.Message)")              
            }

            try{
                Remove-Item -LiteralPath "$($outputFile)_original"
            } catch {
                Write-Host "$($outputFile)_original"
                Write-Host "couldn't delete backup file created by exiftool"
                throw ("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Error deleting BackupFile: $($_.Exception.Message)")
            }   
            WRite-Host $outputFile
            
        } -ArgumentList $row, $path, ${function:CleanPathBreakingSymbols}, ${function:Get-ImageExtension}, $((Get-Job | Sort-Object Id -Descending | Select-Object -First 1).Id)
    }            
}

$failedJobs | Receive-job


