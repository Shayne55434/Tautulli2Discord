Clear-Host

<############################################################
Note - In order for this to work, you must set "api_sql = 1"
       in the Tautulli config file. It will require a restart
       of Tautulli.
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'TopUsersByMediaType'

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
[array]$arrMediaTypes = $objConfig.ScriptSettings.$strScriptName.MediaTypes
[string]$strCount = $objConfig.ScriptSettings.$strScriptName.Count
[string]$strDays = $objConfig.ScriptSettings.$strScriptName.Days
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[string]$strQuery = "
SELECT
CASE
   WHEN friendly_name IS NULL THEN username
   ELSE friendly_name
END AS FriendlyName,
CASE
   WHEN media_type = 'episode' THEN 'TV'
   WHEN media_type = 'movie' THEN 'Movies'
   WHEN media_type = 'track' THEN 'Music'
   ELSE media_type
END AS MediaType,
count(user) AS Plays
FROM (
   SELECT
   session_history.user,
   session_history.user_id,
   users.username,
   users.friendly_name,
   started,
   session_history_metadata.media_type
   FROM session_history
   JOIN session_history_metadata
      ON session_history_metadata.id = session_history.id
   LEFT OUTER JOIN users
      ON session_history.user_id = users.user_id
   WHERE datetime(session_history.stopped, 'unixepoch', 'localtime') >= datetime('now', '-$strDays days', 'localtime')
   AND users.user_id <> 0
   GROUP BY session_history.reference_id
) AS Results
GROUP BY user, media_type
"

# Get and store results from the query
[object]$objTautulliQueryResults = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=sql&query=$($strQuery)"
[array]$arrTopUsersByMediaType = $objTautulliQueryResults.response.data | Where-Object -Property MediaType -in $arrMediaTypes | Group-Object -Property MediaType

foreach ($group in $arrTopUsersByMediaType) {
   [string]$strBody = $group.Group | Sort-Object -Property plays -Descending | Select-Object -Property FriendlyName, Plays -First $strCount | Out-String
   [object]$objPayload = @{
      content = "**Top $strCount users in $($group.Name)** for the last **$($strDays)** Days!`n``````$strBody``````"
   } | ConvertTo-Json -Depth 4
   
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}