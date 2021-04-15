Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the config file under "[Webhooks]".
$WebhookName = "SABnzbd"

# Log file path
#$SABLog = "C:\Users\Shayne\Google Drive\Plex Stuff\PowerShell\Updated Scripts\SABLog.txt"
$SABLog = "$PSScriptRoot\SABLog.txt"

<############################################################

 Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function SendStringToDiscord {
   [CmdletBinding()]
      param(
         [Parameter(Position = 0, Mandatory)]
         [ValidateNotNullOrEmpty()]
         [string]
         $title,
         
         [Parameter(Position = 1, Mandatory)]
         [ValidateNotNullOrEmpty()]
         [string]
         $body
      )
   
   $Content = @"
$title
``````
$body
``````
"@
   $Content
   $Payload = [PSCustomObject]@{content = $Content}
   try {
      Invoke-RestMethod -Uri $script:DiscordURL -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
      Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord." -ForegroundColor Red
   }
}

# Parse the config file and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.SABnzbd.URL
[string]$apiKey = $config.SABnzbd.APIKey
$apiURL = "http://$URL/sabnzbd/api?apikey=$apiKey&output=json&mode=queue"
$SABnzbdInfo = (Invoke-RestMethod -Method Get -Uri $apiURL).queue
$objResult = @()

if (($SABnzbdInfo.slots).Count -gt 0) {
   $summary = "Downloading " + ($SABnzbdInfo.slots).Count + " items at " + $SABnzbdInfo.speed + "/second. Time remaining: $($SABnzbdInfo.timeleft)"
   
   foreach ($slot in $SABnzbdInfo.slots) {
      $objTemp = [PSCustomObject]@{
         FileName = ($slot.filename).Substring(0, 30) + "..." # This is used to reduce the length, as filenames can be 50+ characters long
         Category = $slot.cat
         SizeLeft= $slot.sizeleft
         Size = $slot.size
         Percentage = $slot.percentage
         TimeLeft = $slot.timeleft
      }
      
      # Add section data results to final object
      $objResult += $objTemp
   }
   
   $body = $objResult | FT -AutoSize | Out-String
   
   # Send to Discord
   SendStringToDiscord -title "**$summary**" -body $body
}
else {
   $summary = "Downloading 0 items at 0 MBps/second. Time remaining: NA"
   $body = "Nothing currently being downloaded."
   
   if(!(Test-Path $SABLog)) { # Log file doesn't exist yet. Create it and send message to Discord
      $body | Out-File -FilePath $SABLog -Force
      
      # Send to Discord
      SendStringToDiscord -title "**$summary**" -body $body
   }
   else { # Log file exists. Run a compare to see if Discord needs to be updated
      $lastSABLog = Get-Content $SABLog | Out-String
      
      if ($lastSABLog -match $body) { # The last message sent to Discord matches the latest message
         Write-Host "Nothing to update."
      }
      else { # The last message sent to Discord does NOT match the latest message. Update the log file and send to Discord
         $body | Out-File -FilePath $SABLog -Force
         
         # Send to Discord
         SendStringToDiscord -title "**$summary**" -body $body
      }
   }
}