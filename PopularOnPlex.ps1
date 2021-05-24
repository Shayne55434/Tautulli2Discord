Clear-Host

# Enter the path to the config file for Tautulli and Discord
#$strPathToConfig = "$PSScriptRoot\config.json"
$strPathToConfig = "C:\Users\Shayne\Google Drive\Plex Stuff\PowerShell\Embeds\config.json"

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
$WebhookName = "PopularOnPlex"

# Top Play Movie/Show Count
$Count = '5'

# How many Days do you want to look Back?
$Days = '30'

# This script requires an API from TheMovieDB.org
$tmdb_api = "925ae90afc31c5d281f0c8b7da82361b"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function SendStringToDiscord($url, $body) {
   $payload = [PSCustomObject]@{
      embeds = $body
   }

   try {
      Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
      Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord." -ForegroundColor Red
      Write-Host $body
   }
}

# Parse the config file and assign variables
$config = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$script:DiscordURL = $config.Webhooks.$WebhookName
[string]$URL = $config.Tautulli.URL
[string]$apiKey = $config.Tautulli.APIKey

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"
$DataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$top_movies = ($DataResult.response.data | Where -property stat_id -eq "popular_movies").rows
$top_tv = ($DataResult.response.data | Where -property stat_id -eq "popular_tv").rows
$top_music = ($DataResult.response.data | Where -property stat_id -eq "popular_music").rows

[System.Collections.ArrayList]$embedTopMovies = @()
foreach ($movie in $top_movies) {
   $tmdbURL = "https://api.themoviedb.org/3/search/movie?api_key=" + $tmdb_api + "&language=en-US&page=1&include_adult=false&year=" + $movie.year + "&query=" + $movie.title

   # Highly inaccurate method and relies on tmdb's ability to match the search title and year, but what other choice do I have?
   $movie_id = (Invoke-RestMethod -Method Get -Uri $tmdbURL).results[0].id
   $tmdbResults = Invoke-RestMethod -Method Get -Uri ("https://api.themoviedb.org/3/movie/" + $movie_id + "?api_key=" + $tmdb_api + "&language=en-US")

   if($tmdbResults.count -eq 0) {
       $embedObject = [PSCustomObject]@{
           color = '13400320'
           title = ($movie.title).Replace('·', '-')
           url = "https://www.themoviedb.org/movie/"
           author = [PSCustomObject]@{
             name = "Open on Plex"
             url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $movie.rating_key
             icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
           }
           description = "Unknown"
           thumbnail = [PSCustomObject]@{url = "https://www.programmableweb.com/sites/default/files/TMDb.jpg"}
           fields = [PSCustomObject]@{
               name = 'Released'
               value = "$($movie.year)"
               inline = $true
           },[PSCustomObject]@{
               name = 'Rating'
               value = "??? :star:'s"
               inline = $true
           }
           footer = [PSCustomObject]@{
               text = 'Updated'
           }
           timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
           #timestamp = "2015-12-31T12:00:00.000Z"
       }
   }
   else {
       $embedObject = [PSCustomObject]@{
           color = '13400320'
           title = ($tmdbResults.original_title).Replace('·', '-')
           url = "https://www.themoviedb.org/movie/$($tmdbResults.id)"
           author = [PSCustomObject]@{
             name = "Open on Plex"
             url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $movie.rating_key
             icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
           }
           description = ($tmdbResults.overview).Replace('·', '-')
           thumbnail = [PSCustomObject]@{url = "https://image.tmdb.org/t/p/w500" + $($tmdbResults.poster_path)}
           fields = [PSCustomObject]@{
               name = 'Released'
               value = "$($tmdbResults.release_date)"
               inline = $true
           },[PSCustomObject]@{
               name = 'Rating'
               value = "$($tmdbResults.vote_average) :star:'s"
               inline = $true
           }
           footer = [PSCustomObject]@{
               text = 'Updated'
           }
           timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
           #timestamp = "2015-12-31T12:00:00.000Z"
       }
   }

   $embedTopMovies.Add($embedObject) | Out-Null
}

$embedTopMovies | FT

[System.Collections.ArrayList]$embedTopTV = @()
foreach ($show in $top_tv) {
   $tmdbURL = "https://api.themoviedb.org/3/search/tv?api_key=" + $tmdb_api + "&language=en-US&page=1&include_adult=false&query=" + $show.title

   # Highly inaccurate method and relies on tmdb's ability to match the search title, but what other choice do I have?
   $tv_id = (Invoke-RestMethod -Method Get -Uri $tmdbURL).results[0].id
   $tmdbResults = Invoke-RestMethod -Method Get -Uri ("https://api.themoviedb.org/3/tv/" + $tv_id + "?api_key=" + $tmdb_api + "&language=en-US")

   if($tmdbResults.count -eq 0) { #This is likely due to RatingKey being changed
       $embedObject = [PSCustomObject]@{
           color = '40635'
           title = $show.title
           #url = "https://www.themoviedb.org/movie/$($json.id)"
           author = [PSCustomObject]@{
             name = "Open on Plex"
             url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $movie.rating_key
             icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
           }
           description = "Unknown"
           #thumbnail = [PSCustomObject]@{url = "https://image.tmdb.org/t/p/w500" + $($json.poster_path)}
           fields = [PSCustomObject]@{
               name = 'Released'
               value = "$($show.year)"
               inline = $true
           },[PSCustomObject]@{
               name = 'Rating'
               value = "??? :star:'s"
               inline = $true
           }
           footer = [PSCustomObject]@{
               text = 'Updated'
           }
           timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
           #timestamp = "2015-12-31T12:00:00.000Z"
       }
   }
   else {
       $embedObject = [PSCustomObject]@{
           color = '40635'
           title = $tmdbResults.original_name
           url = "https://www.themoviedb.org/tv/$($tmdbResults.id)"
           author = [PSCustomObject]@{
             name = "Open on Plex"
             url = "https://app.plex.tv/desktop/#!/server/f811f094a93f7263b1e3ad8787e1cefd99d92ce4/details?key=%2Flibrary%2Fmetadata%2F" + $show.rating_key
             icon_url = "https://styles.redditmedia.com/t5_2ql7e/styles/communityIcon_mdwl2x2rtzb11.png?width=256&s=14a77880afea69b1dac1b0f14dc52b09c492b775"
           }
           description = $tmdbResults.overview
           thumbnail = [PSCustomObject]@{url = "https://image.tmdb.org/t/p/w500" + $($tmdbResults.poster_path)}
           fields = [PSCustomObject]@{
               name = 'Rating'
               value = "$($tmdbResults.vote_average) :star:'s"
               inline = $false
           },[PSCustomObject]@{
               name = 'Seasons'
               value = "$($tmdbResults.number_of_seasons) Seasons "
               inline = $true
           },[PSCustomObject]@{
               name = 'Episodes'
               value = "$($tmdbResults.number_of_episodes) Episodes "
               inline = $true
           },[PSCustomObject]@{
               name = 'Runtime'
               value = "$($tmdbResults.episode_run_time | Select-Object -First 1) Minutes"
               inline = $true
           }
           footer = [PSCustomObject]@{
               text = 'Updated'
           }
           timestamp = ((Get-Date).AddHours(5)).ToString("yyyy-MM-ddTHH:mm:ss.Mss")
           #timestamp = "2015-12-31T12:00:00.000Z"
       }
   }

   $embedTopTV.Add($embedObject) | Out-Null
}

$embedTopTV | FT

#
$Content = @"
**Popular Movies on Plex:**
"@   
$Payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $script:DiscordURL -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
SendStringToDiscord -url $DiscordURL -body $embedTopMovies

$Content = @"
**Popular TV Shows on Plex:**
"@   
$Payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $script:DiscordURL -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
SendStringToDiscord -url $DiscordURL -body $embedTopTV
#>