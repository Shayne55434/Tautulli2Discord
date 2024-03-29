Clear-Host

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'TopPlexStats'

<############################################################
Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
function Push-ObjectToDiscord {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strDiscordWebhook,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [object]$objPayload
   )
   try {
      $null = Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/JSON'
      Start-Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord. $($_)" -ForegroundColor Red
      Write-Host $objPayload
   }
}
function Get-SanitizedString {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strInputString
   )
   # Credit to FS.Corrupt for the initial version of this function. https://github.com/FSCorrupt
   [regex]$regAppendedYear = ' \(([0-9]{4})\)' # This will match any titles with the year appended. I ran into issues with 'Yellowstone (2018)'
   [hashtable]$htbReplaceValues = @{
      'ß' = 'ss'
      'à' = 'a'
      'á' = 'a'
      'â' = 'a'
      'ã' = 'a'
      'ä' = 'a'
      'å' = 'a'
      'æ' = 'ae'
      'ç' = 'c'
      'è' = 'e'
      'é' = 'e'
      'ê' = 'e'
      'ë' = 'e'
      'ì' = 'i'
      'í' = 'i'
      'î' = 'i'
      'ï' = 'i'
      'ð' = 'd'
      'ñ' = 'n'
      'ò' = 'o'
      'ó' = 'o'
      'ô' = 'o'
      'õ' = 'o'
      'ö' = 'o'
      'ø' = 'o'
      'ù' = 'u'
      'ú' = 'u'
      'û' = 'u'
      'ü' = 'u'
      'ý' = 'y'
      'þ' = 'p'
      'ÿ' = 'y'
      '“' = '"'
      '”' = '"'
      '·' = '-'
      ':' = ''
      $regAppendedYear = ''
   }
   
   foreach($key in $htbReplaceValues.Keys){
      $strInputString = $strInputString -Replace($key, $htbReplaceValues.$key)
   }
   return $strInputString
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strCount = $objConfig.ScriptSettings.$strScriptName.Count
[string]$strDays = $objConfig.ScriptSettings.$strScriptName.Days
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey

# Get and store Home Stats from Tautulli
[object]$objTautulliHomeStats = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_home_stats&grouping=1&time_range=$strDays&stats_count=$strCount"
[object]$objTopUsers = ($objTautulliHomeStats.response.data | Where-Object -property stat_id -eq "top_users").rows | Sort-Object -property total_plays -Descending | Select-Object -property friendly_name, total_plays
[object]$objTopPlatforms = ($objTautulliHomeStats.response.data | Where-Object -property stat_id -eq "top_platforms").rows  | Sort-Object -property total_plays -Descending | Select-Object -property platform, total_plays
[object]$objMostConcurrent = ($objTautulliHomeStats.response.data | Where-Object -property stat_id -eq "most_concurrent").rows | Sort-Object -property count -Descending | Select-Object -property title, count

[System.Collections.ArrayList]$arrAllStats = @()
foreach ($user in $objTopUsers) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Users Overall"
      Metric = $user.friendly_name
      Value = "$($user.total_plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($platform in $objTopPlatforms) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top $strCount Platforms"
      Metric = $platform.platform
      Value = "$($platform.total_plays) plays"
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}
foreach ($stat in $objMostConcurrent) {
   [hashtable]$htbCurrentStats = @{
      Group = "Top Concurrent Streams"
      Metric = $stat.title
      Value = $stat.count
   }
   
   # Add section data results to final object
   $null = $arrAllStats.Add($htbCurrentStats)
}

# Group and sort the Array in a logical order
[System.Collections.ArrayList]$arrAllStatsGroupedAndOrdered = @()
foreach ($value in "Top $strCount Users Overall", "Top $strCount Platforms", 'Top Concurrent Streams') {
   [object]$objGroupInfo = ($arrAllStats | ForEach-Object {[PSCustomObject]$_} | Group-Object -property Group | Where-Object {$_.Name -eq $value } | Sort-Object Name)
   if($null -ne $objGroupInfo) {
      $null = $arrAllStatsGroupedAndOrdered.Add($objGroupInfo)
   }
}

# Convert results to string and send to Discord
foreach ($group in $arrAllStatsGroupedAndOrdered) {
   [string]$strBody = $group.group | Select-Object -property Metric, Value | Format-Table -AutoSize -HideTableHeaders | Out-String
   [object]$objPayload = @{
      content = "**$($group.Name)** for the last **$($strDays)** Days!`n``````$strBody``````"
   } | ConvertTo-Json -Depth 4
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}