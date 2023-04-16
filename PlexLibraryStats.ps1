Clear-Host

<############################################################
Note - For this script to include library sizes, you need to
       go into Tautulli > Settings > General > and enable
       "Calculate Total File Sizes". It may take a while for
       Tautulli to update the stats, depending on your
       library sizes.
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = 'PlexLibraryStats'

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
      $null = Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/Json'
      Start-Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord. $($_)" -ForegroundColor Red
      Write-Host $objPayload
   }
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[array]$arrExcludedLibraries = $objConfig.ScriptSettings.$strScriptName.ExcludedLibraries
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[object]$objLibrariesTable = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_libraries_table"
[array]$arrLibraries = $objLibrariesTable.response.data.data | Select-Object section_id, section_name, section_type, count, parent_count, child_count | Where-Object -Property section_name -notin ($arrExcludedLibraries)

# Loop through each library
[System.Collections.ArrayList]$arrLibraryStats = @()
foreach ($Library in $arrLibraries){
   [float]$fltTotalSizeBytes = (Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_library_media_info&section_id=$($Library.section_id)").response.data.total_file_size
   
   if ($fltTotalSizeBytes -ge '1000000000000'){
      [string]$strFormat = 'Tb'
      [float]$fltFormattedSize = [math]::round($fltTotalSizeBytes / 1Tb, 2)
   }
   else{
      [string]$strFormat = 'Gb'
      [float]$fltFormattedSize = [math]::round($fltTotalSizeBytes / 1Gb, 2)
   }
   
   # Fill Temp object with current section data
   $objTemp = [PSCustomObject]@{
      Library = $Library.section_name
      Type = $Library.section_type
      Count = $Library.count
      SeasonAlbumCount= $Library.parent_count
      EpisodeTrackCount = $Library.child_count
      Size = $fltFormattedSize
      Format = $strFormat
   }
   
   # Add section data results to final object
   $arrLibraryStats += $objTemp
}

# Movie Library Stats
if (($arrLibraryStats | Where-Object {$_.Type -eq 'movie'}).Count -gt 0) {
   [System.Collections.ArrayList]$arrMovieLibraryStats = @()
   [PSCustomObject]$objMovieFields = $null
   [hashtable]$htbMovieLibraryStats = @{
      color = '13400320'
      title = 'Movie Libraries'
      timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
   }
   
   foreach ($MovieLibrary in ($arrLibraryStats | Where-Object {$_.Type -eq 'movie'})) {
      $objTempMovieFields = [PSCustomObject]@{
         name = 'Library'
         value = $MovieLibrary.Library
         inline = $true
      },@{
         name = 'Count'
         value = $MovieLibrary.Count
         inline = $true
      },@{
         name = 'Size'
         value = "$($MovieLibrary.Size)$($MovieLibrary.Format)"
         inline = $true
      }
      
      $objMovieFields += $objTempMovieFields
   }
   $null = $htbMovieLibraryStats.Add('fields', $objMovieFields)
   $null = $arrMovieLibraryStats.Add($htbMovieLibraryStats)
   
   [object]$objPayload = @{
      embeds = $arrMovieLibraryStats
   } | ConvertTo-Json -Depth 4
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}

# TV Library Stats
if (($arrLibraryStats | Where-Object {$_.Type -eq 'show'}).Count -gt 0) {
   [System.Collections.ArrayList]$arrTVLibraryStats = @()
   [PSCustomObject]$objTVFields = $null
   [hashtable]$htbTVLibraryStats = @{
      color = '40635'
      title = 'TV Libraries'
      timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
   }
   
   foreach ($TVLibrary in ($arrLibraryStats | Where-Object {$_.Type -eq 'show'})) {
      [PSCustomObject]$objTempTVFields = @{
         name = 'Library'
         value = $TVLibrary.Library
         inline = $false
      },@{
         name = 'Shows'
         value = $TVLibrary.Count
         inline = $true
      },@{
         name = 'Seasons'
         value = $TVLibrary.SeasonAlbumCount
         inline = $true
      },@{
         name = 'Episodes'
         value = $TVLibrary.EpisodeTrackCount
         inline = $true
      },@{
         name = 'Size'
         value = "$($TVLibrary.Size)$($TVLibrary.Format)"
         inline = $false
      }
      
      $objTVFields += $objTempTVFields
   }
   
   $null = $htbTVLibraryStats.Add('fields', $objTVFields)
   $null = $arrTVLibraryStats.Add($htbTVLibraryStats)
   
   [object]$objPayload = @{
      embeds = $arrTVLibraryStats
   } | ConvertTo-Json -Depth 4
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}

# Music Library Stats
if (($arrLibraryStats | Where-Object {$_.Type -eq 'artist'}).Count -gt 0) {
   [System.Collections.ArrayList]$arrMusicLibraryStats = @()
   [PSCustomObject]$objMusicFields = $null
   [hashtable]$htbMusicLibraryStats = @{
      color = '39270'
      title = 'Music Libraries'
      timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
   }
   
   foreach ($MusicLibrary in ($arrLibraryStats | Where-Object {$_.Type -eq 'artist'})) {
      [PSCustomObject]$objTempMusicFields = @{
         name = 'Library'
         value = $MusicLibrary.Library
         inline = $false
      },@{
         name = if($MusicLibrary.Library -match 'book'){'Authors'}else{'Artists'}
         value = $MusicLibrary.Count
         inline = $true
      },@{
         name = if($MusicLibrary.Library -match 'book'){'Books'}else{'Albums'}
         value = $MusicLibrary.SeasonAlbumCount
         inline = $true
      },@{
         name = if($MusicLibrary.Library -match 'book'){'Chapters'}else{'Tracks'}
         value = $MusicLibrary.EpisodeTrackCount
         inline = $true
      },@{
         name = 'Size'
         value = "$($MusicLibrary.Size)$($MusicLibrary.Format)"
         inline = $false
      }
      
      $objMusicFields += $objTempMusicFields
   }
   $null = $htbMusicLibraryStats.Add('fields', $objMusicFields)
   $null = $arrMusicLibraryStats.Add($htbMusicLibraryStats)
   
   [object]$objPayload = @{
      embeds = $arrMusicLibraryStats
   } | ConvertTo-Json -Depth 4
   Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload
}