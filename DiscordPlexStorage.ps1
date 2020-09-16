Clear-Host

# I have been unsuccessful at implementing this script as a Scheduled Task.

# Discord Webhook Prod Uri
$Uri = 'https://discordapp.com/api/webhooks/XXXXXX'

# Enter the drive name to get stats for
$DriveName = "DrivePool"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

$objDriveInfo = New-Object psobject
$objDriveInfo | Add-Member -MemberType NoteProperty -Name FreeSpaceTB -Value $null
$objDriveInfo | Add-Member -MemberType NoteProperty -Name DriveSizeTB -Value $null
$objDriveInfo | Add-Member -MemberType NoteProperty -Name PercentUsed -Value $null
$objDriveInfo | Add-Member -MemberType NoteProperty -Name PercentFree -Value $null

$DriveInfo = Get-WmiObject -Class Win32_logicaldisk | Where-Object -Property VolumeName -eq $DriveName

$objDriveInfo.FreeSpaceTB = [math]::round($DriveInfo.FreeSpace / 1Tb, 2)
$objDriveInfo.DriveSizeTB = [math]::round($DriveInfo.Size / 1Tb, 2)
$objDriveInfo.PercentUsed = [math]::round((($DriveInfo.Size - $DriveInfo.FreeSpace) / $DriveInfo.Size) * 100, 2)
$objDriveInfo.PercentFree = [math]::round(($DriveInfo.FreeSpace / $DriveInfo.Size) * 100, 2)

$StorageInfo = "> Total Storage - $($objDriveInfo.DriveSizeTB)TB`n> Storage Remaining- $($objDriveInfo.FreeSpaceTB)TB`n> Percent Use - $($objDriveInfo.PercentUsed)%`n> Percent Free - $($objDriveInfo.PercentFree)%"

#Generate Content. 
$Content = @"
@everyone
**Storage Info**
$StorageInfo
"@

<#Preview Content
$Content
#>

#Send to Discord
$payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'