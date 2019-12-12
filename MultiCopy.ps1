#copy multiple sources to multiple destinations via a file and robocopy.
#select the file with a format as "source"|"Destination"  (one per line, including quotes) and robocopy will copy and log all the copies.
#No-Op mode can be used to check the paths in the transfer file to make sure they are reachable.

function Write-Log {
  param(
    [switch]$NoHeaders,
    [switch]$IsTag,
    $logMessage,
    $title,
    $logFilePath
  )

  $timeStamp = (Get-Date).ToString("[MM-dd-yyyy @ hh:mm:ss tt]")
  $LogData = "$($timeStamp)[$title] - $($logMessage)"

  if($NoHeaders) {
    $logMessage | Out-File -Encoding utf8 -Append -FilePath $logFilePath
  }
  else {

    if($IsTag) {
      $tagData = @"

*********************************************************
$LogData
*********************************************************
"@

      $tagData | Out-File -Encoding utf8 -Append -FilePath $logFilePath
    }
    else {
      $LogData | Out-File -Encoding utf8 -Append -FilePath $logFilePath
    }
  }
}

Function Get-File($initialDirectory, $title)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $filename = New-Object System.Windows.Forms.OpenFileDialog
    $filename.Title = $title
    $filename.Multiselect = $true
    $filename.InitialDirectory = $initialDirectory

    if($filename.ShowDialog() -eq "OK") {
        $file += $filename.FileNames
    }
    return $file
}

Function Get-PreSummary
{
  param(
    $transferData
  )

  [string[]]$preS = $null
  $preS += ""

  $sourceList += $TransferData | % {$_.Split('|')[0]}
  $longestSource = ($sourceList | Measure -Maximum -Property Length).Maximum

  ForEach($td in $transferData) {
    $tdArray = $td.Split('|')
    [int]$offset = $longestSource - $tdArray[0].Length
    $line = $($tdArray[0])
    for(;$offset -ge 0; $offset--) {
      $line += " "
    }
    $line += " -> $($tdArray[1])"
    $preS += $line
  }

  $preS += ""
  return $preS
}
#>>----- SCRIPT START -----<<
clear
Write-Host "I recommend running no-op mode before a transfer to make sure all paths in the transfer file are accessible" -Foregroundcolor Yellow -Backgroundcolor Black
Write-Host ""
$noopMode = Read-Host("No Operation Mode?")

if($noopMode -eq "Y") {
  Write-host "NO-OP : Select transfer data file"
  $sdFile = Get-File $pwd.Path "Select Transfer Data File"
  if($sdFile -ne $null) {
      function CheckPath
      {
        param(
          [string]$path
        )
        if(Test-Path($tdArray[0])) {
          Write-Host "Good Path: $path" -Foregroundcolor Green
        }
        else {
          Write-Host "Bad Path: $path" -Foregroundcolor Red
        }
      }
      $TransferData = Get-Content $sdFile
      foreach($td in $TransferData) {
        $tdArray = $td.Split('|')
        $tdArray[0] = $tdArray[0].Replace('"',"")
        $tdArray[1] = $tdArray[1].Replace('"',"")

        CheckPath $tdArray[0]
        CheckPath $tdArray[1]
      }

      Write-Host ""
      Write-Host "Fix any " -NoNewLine
      Write-Host "red" -NoNewLine -Foregroundcolor Red
      Write-Host " path lines above before attempting the transfer. They will fail."
      Write-Host ""
  }
}
else {
  clear
  Import-Module BitsTransfer
  Write-host "Select transfer data file"
  $timeStamp = (Get-Date).ToString("MM-dd-yyyy_hh-mm-ss-tt")
  $logFile = "$($pwd.Path)\MultiCopy_$($timeStamp).log"
  $sdFile = Get-File $pwd.Path "Select Transfer Data File"
  $CopyStartDate = ""
  $CopyEndDate = ""

  if($sdFile -ne $null) {
    Write-host "Log File: $($logFile)"
    Write-Host ""
    $customLogName = Read-Host("Change Log Name? [y/N]")
    if($customLogName -eq "Y") {
      $logName = Read-Host("Enter new Log Name")
      if($logName -ne "") {
        $logFile = "$($pwd.Path)\$($logName).log"
      }
    }
    $script:moveMode = $false
    $useMoveMode = Read-Host("Use Move mode? (delete source files after copy) [y/N]")
    if($useMoveMode -eq "Y") {
      $script:moveMode = $true
      Write-Log "Using Move-Mode" "Setup" $logFile
    }

    clear
    Write-host "Log File: $($logFile)"
    Write-Host ""
    Write-Host "Copy Summary, Please review before continuing:"
    Write-Host ""

    Write-Log "Loading transfer data..." "Setup" $logFile
    $TransferData = Get-Content $sdFile

    if($TransferData -ne $null) {
      Write-Log "transfer data loaded" "Setup" $logFile
      Write-Log "Pre-Copy Summary" "Setup" $logFile

      $PreSummary = Get-PreSummary $TransferData
      $PreSummary
      Write-Log -NoHeaders $PreSummary "" $logFile

      Write-host ""
      if($script:moveMode) {
        Write-Warning "You are using move mode. Source files will be deleted after coping"
      }
      $confirmCopy = Read-Host("Start Copy? [y/N]")
      if($confirmCopy -eq "Y") {
        Write-Log "Start Copy Confirmed" "Setup" $logFile
        $CopyStartDate = Get-Date
        foreach($td in $TransferData) {
          $tdArray = $td.Split('|')
          $tdArray[0] = $tdArray[0].Replace('"',"")
          $tdArray[1] = $tdArray[1].Replace('"',"")

          Write-Host "Starting Copy: $($tdArray[0]) -> $($tdArray[1])" -Foregroundcolor Cyan
          Write-Log -IsTag "Starting Copy: $($tdArray[0]) -> $($tdArray[1])" "File Transfer" $logFile

          if(Test-Path($tdArray[0])) {
            Write-Log "Source Path Found" "File Transfer" $logFile
            if(Test-Path($tdArray[1])) {
              $pathInfo = $tdArray[0].Split('\')
              Write-Log "Destination Path Found" "File Transfer" $logFile
              $tdArray[1] += "\$($pathInfo[$pathInfo.Length-1])"
              if(Test-Path($tdArray[1])) {
                Write-Host ""
                Write-Host "A folder or file named '$($pathInfo[$pathInfo.Length-1])' already exists at '$($tdArray[1])'." -Foregroundcolor Yellow
                Write-Host ""
                $confirm = Read-Host("Copy files into this folder or replace file? [y/N]")
                if($confirm -eq "Y") {
                  Write-Log "Copying into existing dir or overwriting file: $($tdArray[1])" "File Transfer" $logFile
                  if($script:moveMode) {
                    if((gi "$($tdArray[0])").Mode -eq "d-----") {
                      robocopy "$($tdArray[0])" "$($tdArray[1])" /S /tee /move /log+:"$($logFile)"
                    }
                    else {
                      #move file
                      Start-BitsTransfer -Source "$($tdArray[0])" -Destination "$($tdArray[1])" -Description "$($tdArray[0])"  -DisplayName "Moving File..."
                      if((Test-Path($($tdArray[1]))) -eq $true) {
                        Write-Host "$($tdArray[0]) Moved Successfully" -Foregroundcolor Green
                        Remove-Item "$($tdArray[0])" -Verbose
                        Write-Host ""
                        Write-Log "File move Completed Successfully" "File Transfer" $logFile
                      }
                      else {
                        Write-Host "$($tdArray[0]) Failed to Move" -Foregroundcolor Red
                        Write-Log "File move Failed" "File Transfer" $logFile
                      }
                    }
                  }
                  else {
                    if((gi "$($tdArray[0])").Mode -eq "d-----") {
                      robocopy "$($tdArray[0])" "$($tdArray[1])" /S /tee /log+:"$($logFile)"
                    }
                    else {
                      #copy file
                      Start-BitsTransfer -Source "$($tdArray[0])" -Destination "$($tdArray[1])" -Description "$($tdArray[0])"  -DisplayName "Copying File..."
                      if((Test-Path($($tdArray[1]))) -eq $true) {
                        Write-Host "$($tdArray[0]) Copied Successfully" -Foregroundcolor Green
                        Write-Host ""
                        Write-Log "File copy Completed Successfully" "File Transfer" $logFile
                      }
                      else {
                        Write-Host "$($tdArray[0]) Failed to Copy" -Foregroundcolor Red
                        Write-Log "File copy Failed" "File Transfer" $logFile
                      }
                    }
                  }
                }
                else {
                  Write-Log "User skipped copying into existing dir: $($tdArray[1])" "File Transfer" $logFile
                }
              }
              else {
                if((gi "$($tdArray[0])").Mode -eq "d-----") {
                  New-Item -ItemType Directory -Path $tdArray[1]
                  Write-Log "Directory Created: $($tdArray[1])" "File Transfer" $logFile
                }
                if($script:moveMode) {
                  if((gi "$($tdArray[0])").Mode -eq "d-----") {
                    robocopy "$($tdArray[0])" "$($tdArray[1])" /S /tee /move /log+:"$($logFile)"
                  }
                  else {
                    #move file
                    Start-BitsTransfer -Source "$($tdArray[0])" -Destination "$($tdArray[1])" -Description "$($tdArray[0])"  -DisplayName "Moving File..."
                    if((Test-Path($($tdArray[1]))) -eq $true) {
                      Write-Host "$($tdArray[0]) Moved Successfully" -Foregroundcolor Green
                      Remove-Item "$($tdArray[0])" -Verbose
                      Write-Host ""
                      Write-Log "File move Completed Successfully" "File Transfer" $logFile
                    }
                    else {
                      Write-Host "$($tdArray[0]) Failed to Move" -Foregroundcolor Red
                      Write-Log "File move Failed" "File Transfer" $logFile
                    }
                  }
                }
                else {
                  if((gi "$($tdArray[0])").Mode -ne "d-----") {
                    #copy file
                    Start-BitsTransfer -Source "$($tdArray[0])" -Destination "$($tdArray[1])" -Description "$($tdArray[0])"  -DisplayName "Copying File..."
                    if((Test-Path($($tdArray[1]))) -eq $true) {
                      Write-Host "$($tdArray[0]) Copied Successfully" -Foregroundcolor Green
                      Write-Host ""
                      Write-Log "File copy Completed Successfully" "File Transfer" $logFile
                    }
                    else {
                      Write-Host "$($tdArray[0]) Failed to Copy" -Foregroundcolor Red
                      Write-Log "File copy Failed" "File Transfer" $logFile
                    }
                  }
                  else {
                    robocopy "$($tdArray[0])" "$($tdArray[1])" /S /tee /log+:"$($logFile)"
                  }
                }
              }
            }
            else {
              Write-Warning "Could not find destination path '$($tdArray[1])' - Aborting this copy"
              Write-Log "Could not find destination path '$($tdArray[1])' - Aborting this copy" "File Transfer" $logFile
            }
          }
          else {
            Write-Warning "Could not find source path '$($tdArray[0])' - Aborting this copy"
            Write-Log "Could not find source path '$($tdArray[0])' - Aborting this copy" "File Transfer" $logFile
          }
        }
        $CopyEndDate = Get-Date
        $ElapsedTransferTime = NEW-TIMESPAN -Start $CopyStartDate -End $CopyEndDate | select Days,Hours,Minutes,Seconds,Milliseconds
        Write-host ""
        Write-Host "All Copies Completed"
        Remove-Module BitsTransfer
        Write-Host ""
        Write-Host "-- Total Copy Time --"
        $ElapsedTransferTime
        Write-Log "All Copies Completed" "File Transfer" $logFile
        Write-Log "Elapsed Copy Time: $($ElapsedTransferTime.Days) Days - $($ElapsedTransferTime.Hours) Hours - $($ElapsedTransferTime.Minutes) Minutes - $($ElapsedTransferTime.Seconds) Seconds - $($ElapsedTransferTime.Milliseconds) Milliseconds" "File Transfer" $logFile

        Write-Host "Loading log file..."
        $logFileData = gc $logFile
        $cPos = $host.UI.RawUI.CursorPosition
        $totalLines = $logFileData.Count
        $progress = 0
        Write-Host "Updating log file to remove percentages..."
        $logFileData | % {
          $line = $_
          if($line.Contains("%") -eq $false) {
            [string[]]$logStuff += $line
          }
          $logFileData = $logStuff
          $progress += 1
          $percentage = [Math]::Floor(($progress/$totalLines) * 100)
          $host.UI.RawUI.CursorPosition = $cPos
          Write-Host "Updating log file to remove percentages... $($progress.ToString())/$($totalLines.ToString()) $($percentage)%"
        }
        Write-Host "Saving log file..."
        $logFileData | Set-Content $logFile
        Write-Host "Done"
      }
      else {
        Write-Host "Copy aborted!" -Foregroundcolor Red
        Write-Log "Copy aborted!" "Setup" $logFile
      }
    }
    else {
      Write-Warning "Error loading transfer data"
      Write-Log "Error loading transfer data" "Get File Content" $logFile
    }
  }
  else {
    Write-Warning "Could not find file."
  }
}
#robocopy command
#robocopy "source" "destination" /S /tee /log+:"copy.log"
Write-Host ""
Read-Host("Press [Enter] to close...")
