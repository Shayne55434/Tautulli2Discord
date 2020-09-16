Clear-Host

# Top Play Movie/Show Count
$Count = '10'

# How many Days do you want to look Back?
$Days = '30'

#Discord Webhook Prod Uri
$Uri = "https://discord.com/api/webhooks/XXXXXX"

#Tautulli URL with port
$URL = "XXXXXX"

#Tautulli API Key
$apiKey='XXXXXX'

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# Clear previously used variables
$MovieList = $null
$ShowList = $null
$artistList = $null
$platformList = $null
$StreamList = $null
$TracksUserContent = $null
$RecentList = $null
$TsortList = $null
$TUserList = $null
$MSUserList = $null
$MSsortList = $null
$MSUserContent = $null

# Complete the API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$top_movies = ($dataResult.response.data | Where -property stat_id -eq "top_movies").rows
$top_tv = ($dataResult.response.data | Where -property stat_id -eq "top_tv").rows
$top_music = ($dataResult.response.data | Where -property stat_id -eq "top_music").rows
$top_users = ($dataResult.response.data | Where -property stat_id -eq "top_users").rows
$top_platforms = ($dataResult.response.data | Where -property stat_id -eq "top_platforms").rows
$most_concurrent = ($dataResult.response.data | Where -property stat_id -eq "most_concurrent").rows
$recently_watched = ($dataResult.response.data | Where -property stat_id -eq "last_watched").rows

# Create empty object
$MSsortList = '' | Select-Object -Property  Count, Name
$TsortList = '' | Select-Object -Property  Count, Name
$MSsortResult = @()
$TsortResult = @()

# This section is not currently working as intended. The API has some numbers wrong
foreach ($user in $top_users) {
   $ID = $user.user_id
   $apiURLv2 = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_by_date&user_id=$ID&time_range=$Days"
   $Userdata = Invoke-RestMethod -Method Get -Uri $apiURLv2
   $MSPlaycount = (($Userdata.response.data.series | Where -Property name -NotMatch 'Music').data | Measure-Object -Sum).Sum.ToString()
   $TPlaycount = (($Userdata.response.data.series | Where -Property name -Match 'Music').data | Measure-Object -Sum).Sum.ToString()
   
   $MSobjTemp = $MSsortList | Select-Object *
   $TobjTemp = $TsortList | Select-Object *
   
   $MSobjTemp.Count = $MSPlaycount
   $MSobjTemp.Name = $user.friendly_name
   
   $TobjTemp.Count = $TPlaycount
   $TobjTemp.Name = $user.friendly_name
   
   $MSsortResult += $MSobjTemp
   $TsortResult += $TobjTemp
}

$MSsortList = $MSsortResult | Sort-Object {[int]$_.count} -Descending
$TsortList = $TsortResult | Sort-Object {[int]$_.count} -Descending


foreach ($Row in $MSsortList) {
   if ($Row) {
      $MSUserList += "> $($Row.Name) - **$($Row.Count)** Plays`n"
   }
}

foreach ($Row in $TsortList) {
   if ($Row -and $Row.Count -notlike '0') {
      $TUserList += "> $($Row.Name) - **$($Row.Count)** Plays`n" 
   }
}

foreach ($movie in $top_movies) {
   $MovieList += "> $($movie.title) - **$($movie.total_plays)** Plays`n"
}

foreach ($show in $top_tv) {
   $ShowList += "> $($show.title) - **$($show.total_plays)** Plays`n"
}

foreach ($artist in $top_music) {
   $artistList += "> $($artist.title) - **$($artist.total_plays)** Plays`n"
}

foreach ($platform in $top_platforms) {
   $platformList += "> $($platform.platform) - **$($platform.total_plays)** Plays`n"
}

foreach ($stream in $most_concurrent) {
   $StreamList += "> $($stream.title) - **$($stream.count)**`n"
}

foreach ($recent in $recently_watched) {
   if ($recent.media_type -eq 'episode') {
      $mediaType = 'TV Show'
   }
   elseif ($recent.media_type -eq 'movie') {
      $mediaType = 'Movie'
   }
   $RecentList += "> $($recent.friendly_name) streamed the $mediaType **$($recent.title)**`n"
}

#using module PSDsHook to generate Content. 
$MovieContent = @"
Top $Count played **Movies** in the last $Days Days!
$MovieList
"@

$ShowContent = @"
Top $Count **Shows** in the last $Days Days!
$ShowList
"@

$MSUserContent = @"
Top $Count **Users** in Movies & Shows in the last $Days Days!
$MSUserList
"@

$TracksUserContent = @"
Top $Count **Users** in Music in the last $Days Days!
$TUserList
"@

$ArtistContent = @"
Top $Count **Artists** in the last $Days Days!
$artistList
"@

$PlatformContent = @"
Top $Count **Platforms** in the last $Days Days!
$platformList
"@

$StreamContent = @"
Top **Concurrent Streams** in the last $Days Days!
$StreamList
"@

$RecentContent = @"
$Count **Most Recent Streams**!
$RecentList
"@

<# Preview Content
$MovieContent
$ShowContent
$MSUserContent
$TracksUserContent
$ArtistContent
$PlatformContent
$StreamContent
$RecentContent
#>

#Send top 10 Movies to Discord
$MoviePayload = [PSCustomObject]@{content = $MovieContent}
Invoke-RestMethod -Uri $uri -Body ($MoviePayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send top 10 Shows to Discord
$ShowPayload = [PSCustomObject]@{content = $ShowContent}
Invoke-RestMethod -Uri $uri -Body ($ShowPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

Sleep -Seconds 1

#Send top 10 Artists to Discord
$ArtistPayload = [PSCustomObject]@{content = $ArtistContent}
Invoke-RestMethod -Uri $uri -Body ($ArtistPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send Movie Show top 10 Users to Discord
$UserPayload = [PSCustomObject]@{content = $MSUserContent}
Invoke-RestMethod -Uri $uri -Body ($UserPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

Sleep -Seconds 1

#Send Tracks top 10 Users to Discord
$UserPayload = [PSCustomObject]@{content = $TracksUserContent}
Invoke-RestMethod -Uri $uri -Body ($UserPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send top 10 Platforms to Discord
$PlatformPayload = [PSCustomObject]@{content = $PlatformContent}
Invoke-RestMethod -Uri $uri -Body ($PlatformPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

Sleep -Seconds 1

#Send top Concurrent Streams to Discord
$StreamPayload = [PSCustomObject]@{content = $StreamContent}
Invoke-RestMethod -Uri $uri -Body ($StreamPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send Most Recent Streams to Discord
$RecentPayload = [PSCustomObject]@{content = $RecentContent}
Invoke-RestMethod -Uri $uri -Body ($RecentPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
#>