Clear-Host

# Top Play Movie/Show Count
$Count = '10'

# How many Days do you want to look Back?
$Days = '10'

#Discord Webhook Prod Uri
$Uri = "https://discord.com/api/webhooks/XXXXXX"

#Tautulli URL with port
$URL = "XXXXXX"

#Tautulli API Key
$apiKey='XXXXXX'

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

#Clear previously used variables
$MovieList = $null
$ShowList = $null
$UserList = $null
$trackList = $null
$platformList = $null
$StreamList = $null

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$top_movies = ($dataResult.response.data | Where -property stat_id -eq "top_movies").rows
$top_tv = ($dataResult.response.data | Where -property stat_id -eq "top_tv").rows
$top_music = ($dataResult.response.data | Where -property stat_id -eq "top_music").rows
$top_users = ($dataResult.response.data | Where -property stat_id -eq "top_users").rows
$top_platforms = ($dataResult.response.data | Where -property stat_id -eq "top_platforms").rows
$most_concurrent = ($dataResult.response.data | Where -property stat_id -eq "most_concurrent").rows

foreach ($movie in $top_movies) {
   $MovieList += "> $($movie.title) - **$($movie.total_plays)** Plays`n"
}

foreach ($show in $top_tv) {
   $ShowList += "> $($show.title) - **$($show.total_plays)** Plays`n"
}

foreach ($track in $top_music) {
   $trackList += "> $($track.title) - **$($track.total_plays)** Plays`n"
}

foreach ($user in $top_users) {
   $userList += "> $($user.friendly_name) - **$($user.total_plays)** Plays`n"
}

foreach ($platform in $top_platforms) {
   $platformList += "> $($platform.platform) - **$($platform.total_plays)** Plays`n"
}

foreach ($stream in $most_concurrent) {
   $StreamList += "> $($stream.title) - **$($stream.count)**`n"
}

$MovieContent = @"
Top $Count played **Movies** in the last $Days Days!
$MovieList
"@

$ShowContent = @"
Top $Count played **Shows** in the last $Days Days!
$ShowList
"@

$UserContent = @"
Top $Count **Users** in the last $Days Days!
$UserList
"@

$TrackContent = @"
Top $Count **Artists** in the last $Days Days!
$trackList
"@

$PlatformContent = @"
Top $Count **Platforms** in the last $Days Days!
$platformList
"@

$StreamContent = @"
Top **Concurrent Streams** in the last $Days Days!
$StreamList
"@

<#Preview Content
$MovieContent
$ShowContent
$UserContent
$TrackContent
$PlatformContent
$StreamContent
#>

#Send top 10 Movies to Discord
$MoviePayload = [PSCustomObject]@{content = $MovieContent}
Invoke-RestMethod -Uri $uri -Body ($MoviePayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send top 10 Shows to Discord
$ShowPayload = [PSCustomObject]@{content = $ShowContent}
Invoke-RestMethod -Uri $uri -Body ($ShowPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send top 10 Users to Discord
$UserPayload = [PSCustomObject]@{content = $UserContent}
Invoke-RestMethod -Uri $uri -Body ($UserPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#To avoid being rate limited, we will wait 3 seconds before sending more.
Sleep -Seconds 3

#Send top 10 Tracks to Discord
$TrackPayload = [PSCustomObject]@{content = $TrackContent}
Invoke-RestMethod -Uri $uri -Body ($TrackPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'


#Send top 10 Platforms to Discord
$PlatformPayload = [PSCustomObject]@{content = $PlatformContent}
Invoke-RestMethod -Uri $uri -Body ($PlatformPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

#Send top Concurrent Streams to Discord
$StreamPayload = [PSCustomObject]@{content = $StreamContent}
Invoke-RestMethod -Uri $uri -Body ($StreamPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
#>