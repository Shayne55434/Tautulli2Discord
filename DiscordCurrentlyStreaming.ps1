Clear-Host

#Discord Webhook Prod Uri
$Uri = "https://discord.com/api/webhooks/XXXXXX"

#Tautulli URL with port
$URL = "XXXXXX"

#Tautulli API Key
$apiKey='XXXXXX'

#Log file path
$StreamLog = "XXXXXX"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

#Clear previously used variables
$StreamList = $null

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_activity"

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$streams = $dataResult.response.data.sessions | select user, friendly_name, full_title, video_decision, progress_percent -Unique

foreach ($stream in $streams){
   $videoDecision = ($stream.video_decision).Replace('transcode', 'transcod')
   $StreamList += "$($stream.friendly_name) is $($videoDecision)ing **$($stream.full_title)** - $($stream.progress_percent)%`n"
}

if ($StreamList -eq $null -or $StreamList -eq "") {
   $StreamContent = @"
Nothing is currently streaming
"@
}
else {
   $StreamContent = @"
Current streams:
$StreamList
"@
}

<#Preview content
$StreamContent
#>


if (Test-Path $StreamLog) {
   $lastStreamList = Get-Content $StreamLog | Out-String
   
   if (($StreamContent -match "Nothing is currently streaming") -and ($lastStreamList -match "Nothing is currently streaming")) {
      Write-Host "Nothing to update"
   }
   else {
      #Update the log file
      $StreamContent | Out-File -FilePath $StreamLog -Force
      $StreamPayload = [PSCustomObject]@{content = $StreamContent}
      
      #Send Concurrent Streams to Discord
      Invoke-RestMethod -Uri $uri -Body ($StreamPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
   }
}