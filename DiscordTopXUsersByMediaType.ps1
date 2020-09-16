Clear-Host

<############################################################

Note - In order for this to work, you must set "api_sql = 1"
       in the Tautulli config file. It will require a restart
       of Tautulli.

#############################################################>

# Top Play Movie/Show Count
$Count = '10'

# How many Days do you want to look Back?
$Days = '30'

#Discord Webhook Prod Uri
$Uri = "https://discord.com/api/webhooks/XXXXXX"

#Tautulli URL with port
$URL = "XXXXXX"

#Tautulli API Key
$apiKey = 'XXXXXX'

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# This section gets plays by media type
$query = "
SELECT
CASE
   WHEN friendly_name IS NULL THEN username
   ELSE friendly_name
END AS friendly_name,
CASE
   WHEN media_type = 'episode' THEN 'TV Show'
   WHEN media_type = 'movie' THEN 'Movie'
   WHEN media_type = 'track' THEN 'Music'
   ELSE media_type
END AS media_type,
count(user) AS plays
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
   WHERE datetime(session_history.stopped, 'unixepoch', 'localtime') >= datetime('now', '-$Days days', 'localtime')
   AND users.user_id <> 0
   GROUP BY session_history.reference_id
) AS Results
GROUP BY user, media_type
"

# Complete API URL for SQL querying
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query

$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$TopUsers_Movies = $DataResult.response.data | Where-Object -Property media_type -EQ 'Movie' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $count
$TopUsers_TV = $DataResult.response.data | Where-Object -Property media_type -EQ 'TV Show' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $count
$TopUsers_Music = $DataResult.response.data | Where-Object -Property media_type -EQ 'Music' | Sort-Object -Property plays -Descending | Select-Object -Property friendly_name, media_type, plays -First $count

# This section gets all other information

# Clear previously used variables
$UserMoviePlays = $null
$UserTVPlays = $null
$UserMusicPlays = $null
$MovieList = $null
$ShowList = $null
$UserList = $null
$ArtistList = $null
$PlatformList = $null
$StreamList = $null

# Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"

$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$top_movies = ($DataResult.response.data | Where -property stat_id -eq "top_movies").rows
$top_tv = ($DataResult.response.data | Where -property stat_id -eq "top_tv").rows
$top_music = ($DataResult.response.data | Where -property stat_id -eq "top_music").rows
$top_users = ($DataResult.response.data | Where -property stat_id -eq "top_users").rows
$top_platforms = ($DataResult.response.data | Where -property stat_id -eq "top_platforms").rows
$most_concurrent = ($DataResult.response.data | Where -property stat_id -eq "most_concurrent").rows

foreach ($user in $TopUsers_Movies) {
   $UserMoviePlays += "> $($user.friendly_name) - **$($user.plays)** Plays`n"
}

foreach ($user in $TopUsers_TV) {
   $UserTVPlays += "> $($user.friendly_name) - **$($user.plays)** Plays`n"
}

foreach ($user in $TopUsers_Music) {
   $UserMusicPlays += "> $($user.friendly_name) - **$($user.plays)** Plays`n"
}

foreach ($movie in $top_movies) {
   # Sanitize the movie title. I ran into an issue with "WALL·E" and it would not send to Discord.
   $CleanMovieTitle = $movie.title `
      -replace '·', ' ' `
      -replace 'ö','oe' `
      -replace 'ä','ae' `
      -replace 'ü','ue' `
      -replace 'ß','ss' `
      -replace 'Ö','Oe' `
      -replace 'Ü','Ue' `
      -replace 'Ä','Ae' `
      -replace 'é','e'
   $RatingKey = $movie.rating_key

   # This section gets TMDB Url
   $query = "
   SELECT themoviedb_url
   FROM themoviedb_lookup 
   WHERE rating_key = '$RatingKey'
   "
   
   # Complete API URL for SQL querying
   $apiSQLQueryURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query
   $SQLQuerydataResult = Invoke-RestMethod -Method Get -Uri $apiSQLQueryURL
   $tmdbURL = $SQLQuerydataResult.response.data.themoviedb_url
   
   if ($tmdbURL -ne "" -and $tmdbURL -ne $null) {
      $MovieList += "> [$CleanMovieTitle](<$tmdbURL>) - **$($Movie.total_plays)** Plays`n"
   }
   else {
      $MovieList += "> $CleanMovieTitle - **$($movie.total_plays)** Plays`n"
   }
}

foreach ($show in $top_tv) {
   # Sanitize the show title.
   $CleanShowTitle = $show.title `
      -replace '·', ' ' `
      -replace 'ö','oe' `
      -replace 'ä','ae' `
      -replace 'ü','ue' `
      -replace 'ß','ss' `
      -replace 'Ö','Oe' `
      -replace 'Ü','Ue' `
      -replace 'Ä','Ae' `
      -replace 'é','e'
   $RatingKey = $show.rating_key

   # This section gets TMDB Url
   $query = "
   SELECT themoviedb_url
   FROM themoviedb_lookup 
   WHERE rating_key = '$RatingKey'
   "
   
   #Complete API URL for SQL querying
   $apiSQLQueryURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query
   $SQLQuerydataResult = Invoke-RestMethod -Method Get -Uri $apiSQLQueryURL
   $tmdbURL = $SQLQuerydataResult.response.data.themoviedb_url
   
   if ($tmdbURL -ne "" -and $tmdbURL -ne $null) {
      $ShowList += "> [$CleanShowTitle](<$tmdbURL>) - **$($show.total_plays)** Plays`n"
   }
   else {
      $ShowList += "> $CleanShowTitle - **$($show.total_plays)** Plays`n"
   }
}

foreach ($artist in $top_music) {
   $ArtistList += "> $($artist.title) - **$($artist.total_plays)** Plays`n"
}

foreach ($user in $top_users) {
   $UserList += "> $($user.friendly_name) - **$($user.total_plays)** Plays`n"
}

foreach ($platform in $top_platforms) {
   $PlatformList += "> $($platform.platform) - **$($platform.total_plays)** Plays`n"
}

foreach ($stream in $most_concurrent) {
   $StreamList += "> $($stream.title) - **$($stream.count)**`n"
}

$UserContent = @"
Top $Count **Users** overall in the last $Days Days!
$UserList
"@

$UserMovieContent = @"
Top $Count **Users** in Movies for the last $Days Days!
$UserMoviePlays
"@

$UserTVContent = @"
Top $Count **Users** in TV for the last $Days Days!
$UserTVPlays
"@

$UserMusicContent = @"
Top $Count **Users** in Music for the last $Days Days!
$UserMusicPlays
"@

$MovieContent = @"
Top $Count played **Movies** in the last $Days Days!
$MovieList
"@

$ShowContent = @"
Top $Count played **Shows** in the last $Days Days!
$ShowList
"@

$ArtistContent = @"
Top $Count **Artists** in the last $Days Days!
$ArtistList
"@

$PlatformContent = @"
Top $Count **Platforms** in the last $Days Days!
$platformList
"@

$StreamContent = @"
Top **Concurrent Streams** in the last $Days Days!
$StreamList
"@

# Preview Content
$UserContent
$UserMovieContent
$UserTVContent
$UserMusicContent
$MovieContent
$ShowContent
$ArtistContent
$PlatformContent
$StreamContent
#>

# Send top Users to Discord
$Payload = [PSCustomObject]@{content = $UserContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

# Send top Users for Movies to Discord
$Payload = [PSCustomObject]@{content = $UserMovieContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

# Send top Users for TV to Discord
$Payload = [PSCustomObject]@{content = $UserTVContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

Sleep -Seconds 2

# Send top Users for Music to Discord
$Payload = [PSCustomObject]@{content = $UserMusicContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

# Send top Movies to Discord
$Payload = [PSCustomObject]@{content = $MovieContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

#Send top Shows to Discord
$Payload = [PSCustomObject]@{content = $ShowContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

Sleep -Seconds 2

# Send top Tracks to Discord
$Payload = [PSCustomObject]@{content = $ArtistContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

# Send top Platforms to Discord
$Payload = [PSCustomObject]@{content = $PlatformContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null

# Send top Concurrent Streams to Discord
$Payload = [PSCustomObject]@{content = $StreamContent}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' | Out-Null
#>