Clear
$ConnectionLostCount = 0
$lostTicker = 10
function CheckConnectionInfo($info)
{
  if($info)
  {
    $info | Tee-Object -Append -FilePath $logFile
  }
  else
  {
    $date = Get-Date -Format g
    $error = "$date --- Connection Lost"
    $error | Tee-Object -Append -FilePath $logFile
    $script:ConnectionLostCount += 1
  }
}

Write-Host "Log file location: $pwd"
Write-Host ""
$thing = Read-Host("Enter an IP address")
do{
  [int]$waitTime = Read-host("Enter a wait time in seconds greater than 1")

}
until($waitTime -gt 1 -and $waitTime -is [int])

$logFile = "$env:ComputerName-TO-$thing.log"
$connectionInfo = ""
echo "--------------------------------------------------------------" | Tee-Object -Append $logFile
$host.ui.RawUI.WindowTitle = "ping: $env:ComputerName  ->  $thing"
echo "Starting new ping: $env:ComputerName  ->  $thing" | Tee-Object -Append $logFile
$connectionInfo = Test-Connection -Count 1 -ComputerName $thing | Format-Table @{Name='TimeStamp';Expression={Get-Date -Format g}},Address,ResponseTime
CheckConnectionInfo $connectionInfo



do
{
    sleep($waitTime)
    $connectionInfo = Test-Connection -Count 1 -ComputerName $thing | Format-Table @{Name='TimeStamp';Expression={Get-Date -Format g}},Address,ResponseTime -HideTableHeaders
    CheckConnectionInfo $connectionInfo

    if($lostTicker -eq 0)
    {
      Write-Host ""
      Write-Host "Connection Lost Count: $ConnectionLostCount" -Foregroundcolor Cyan
      Write-Host ""
      $lostTicker = 10
    }
    else
    {
      $lostTicker -= 1
    }
}
until($false) #loop forever
