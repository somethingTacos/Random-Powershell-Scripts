Add-Type -AssemblyName System.Security
[Reflection.Assembly]::LoadWithPartialName("System.Security")
clear
Write-Host "--[ Base 64 AES Key Gen ]--"
Write-Host ""
[int] $NumberOfKeys = Read-Host("How many keys to generate")

if($NumberOfKeys -ne 0) {
  Write-Host "Keys:"
  Write-Host ""
  $rijndael = new-Object System.Security.Cryptography.RijndaelManaged
  for($i = 0 ; $i -lt $NumberOfKeys; $i++) {
    $rijndael.GenerateKey()
    Write-Host([Convert]::ToBase64String($rijndael.Key))
  }
  $rijndael.Dispose()
}
Write-Host ""
Read-Host("Press [Enter] to exit...")
