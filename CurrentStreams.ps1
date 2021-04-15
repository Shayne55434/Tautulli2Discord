Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the config file under "[Webhooks]".
$WebhookName = "CurrentStreams"

# Log file path
$StreamLog = "$PSScriptRoot\StreamLog.txt"

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
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_activity"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$streams = $dataResult.response.data.sessions | select user, friendly_name, full_title, video_decision, progress_percent, stream_video_full_resolution, media_index, parent_media_index, grandparent_title, media_type -Unique
$objResult = @()

# Loop through each stream
foreach ($stream in $streams) {
   $cleanTitle = $stream.full_title `
      -replace '·', ' ' `
      -replace 'ö','oe' `
      -replace 'ä','ae' `
      -replace 'ü','ue' `
      -replace 'ß','ss' `
      -replace 'Ö','Oe' `
      -replace 'Ü','Ue' `
      -replace 'Ä','Ae' `
      -replace 'é','e' `
      -replace "'", ''
   
   # If the media type is episode, create custom title
   if ($stream.media_type -eq "episode") {
      if ($stream.parent_media_index -lt 10) {
         $season = "0" + $stream.parent_media_index
      }
      else{
         $season = $stream.parent_media_index
      }
      
      if ($stream.media_index -lt 10) {
         $episode = "0" + $stream.media_index
      }
      else{
         $episode = $stream.media_index
      }
      
      $cleanTitle = $stream.grandparent_title + " - S" + $season + "E" + $episode
   }
   
   $objTemp = [PSCustomObject]@{
      User = ($stream.friendly_name).Split("@")[0]
      Title = $cleanTitle
      VideoDecision = ($stream.video_decision).Replace('copy','direct stream')
      Resolution = $stream.stream_video_full_resolution
      Progress = "$($stream.progress_percent)%"
   }
   
   # Add line results to final object
   $objResult += $objTemp
}

if ($objResult.Count -gt 0) {
   $body = $objResult | FT -AutoSize | Out-String
}
else {
   $body = "Nothing is currently streaming"
}

if (!(Test-Path $StreamLog)) {
   # Create the log file
   $body | Out-File -FilePath $StreamLog -Force
   
   # Send to Discord
   SendStringToDiscord -title "**Current Streams:**" -body $body
}
else {
   $lastStreamList = Get-Content $StreamLog | Out-String
   
   if (($body -match "Nothing is currently streaming") -and ($lastStreamList -match "Nothing is currently streaming")) {
      Write-Host "Nothing to update"
   }
   else {
      # Update the log file
      $body | Out-File -FilePath $StreamLog -Force
      
      # Send to Discord
      SendStringToDiscord -title "**Current Streams:**" -body $body
   }
}