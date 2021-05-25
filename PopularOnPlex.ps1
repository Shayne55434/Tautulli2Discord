Clear-Host

# Enter the path to the config file for Tautulli and Discord
$strPathToConfig = "$PSScriptRoot\config.json"

# Discord webhook name. This should match the webhook name in the INI file under "[Webhooks]".
$WebhookName = "PopularOnPlex"

# Top Play Movie/Show Count
$Count = '5'

# How many Days do you want to look Back?
$Days = '30'

# This script requires an API from TheMovieDB.org
$tmdb_api = "XXXXXXXXXXXXXXXXXXXXXXXX"

<############################################################

    Do NOT edit lines below unless you know what you are doing!

############################################################>

# Define the functions to be used
function SendStringToDiscord($url, $body) {
   $payload = [PSCustomObject]@{
      embeds = $body
   }

   try {
      Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json' -ErrorVariable RestError
      Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord.... Error Message:" -ForegroundColor Yellow
      write-host "$RestError" -ForegroundColor Red
     Write-Host ''
     Write-Host "Message Body:" -ForegroundColor Yellow
     Write-Host $body
   }
}
function SanitizeTitle{
    Param(
        [String]$inputString
    )
    $replaceTable = @{"ß"="ss";"à"="a";"á"="a";"â"="a";"ã"="a";"ä"="a";"å"="a";"æ"="ae";"ç"="c";"è"="e";"é"="e";"ê"="e";"ë"="e";"ì"="i";"í"="i";"î"="i";"ï"="i";"ð"="d";"ñ"="n";"ò"="o";"ó"="o";"ô"="o";"õ"="o";"ö"="o";"ø"="o";"ù"="u";"ú"="u";"û"="u";"ü"="u";"ý"="y";"þ"="p";"ÿ"="y"}

    foreach($key in $replaceTable.Keys){
        $inputString = $inputString -Replace($key,$replaceTable.$key)
    }
    return $inputString
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
  #Sanitize the movie title. I ran into an issue with "WALLÂ·E" and it would not send to Discord.
  $CleanMovieTitle = SanitizeTitle -inputString $movie.title
    
  if ($movie.year) {
    $tmdbURL = "https://api.themoviedb.org/3/search/movie?api_key=" + $tmdb_api + "&language=en-US&page=1&include_adult=false&year=" + $movie.year + "&query=" + $CleanMovieTitle
  }
  Else{
    $tmdbURL = "https://api.themoviedb.org/3/search/movie?api_key=" + $tmdb_api + "&language=en-US&page=1&include_adult=false&query=" + $CleanMovieTitle
  }
   # Highly inaccurate method and relies on tmdb's ability to match the search title and year, but what other choice do I have?
   $movie_id = (Invoke-RestMethod -Method Get -Uri $tmdbURL).results[0].id
   $tmdbResults = Invoke-RestMethod -Method Get -Uri ("https://api.themoviedb.org/3/movie/" + $movie_id + "?api_key=" + $tmdb_api + "&language=en-US")
   $tmdbResultstitle = SanitizeTitle -inputString $tmdbResults.title
   
   if($tmdbResults.count -eq 0) {
       $embedObject = [PSCustomObject]@{
           color = '13400320'
           title = $CleanMovieTitle.Replace('·', '-')
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
           title = $tmdbResultstitle.Replace('·', '-')
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
  #Sanitize the movie title. I ran into an issue with "WALLÂ·E" and it would not send to Discord.
  $CleanShowTitle = SanitizeTitle -inputString $show.title
    
  if ($show.year) {
    $tmdbURL = "https://api.themoviedb.org/3/search/tv?api_key=" + $tmdb_api + "&language=en-US&page=1&include_adult=false&year=" + $show.year + "&query=" + $CleanShowTitle
  }
  Else{
    $tmdbURL = "https://api.themoviedb.org/3/search/tv?api_key=" + $tmdb_api + "&language=en-US&page=1&include_adult=false&query=" + $CleanShowTitle
  }

   # Highly inaccurate method and relies on tmdb's ability to match the search title, but what other choice do I have?
   $tv_id = (Invoke-RestMethod -Method Get -Uri $tmdbURL).results[0].id
   $tmdbResults = Invoke-RestMethod -Method Get -Uri ("https://api.themoviedb.org/3/tv/" + $tv_id + "?api_key=" + $tmdb_api + "&language=en-US")

   $tmdbResultsname = SanitizeTitle -inputString $tmdbResults.name

   if($tmdbResults.count -eq 0) { #This is likely due to RatingKey being changed
       $embedObject = [PSCustomObject]@{
           color = '40635'
           title = $CleanShowTitle
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
           title = $tmdbResultsname
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
$MovieContent = @"
**Popular Movies on Plex:**
"@   
$MoviePayload = [PSCustomObject]@{content = $MovieContent}
Invoke-RestMethod -Uri $script:DiscordURL -Body ($MoviePayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
SendStringToDiscord -url $DiscordURL -body $embedTopMovies

$ShowContent = @"
**Popular TV Shows on Plex:**
"@   
$ShowPayload = [PSCustomObject]@{content = $ShowContent}
Invoke-RestMethod -Uri $script:DiscordURL -Body ($ShowPayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
SendStringToDiscord -url $DiscordURL -body $embedTopTV
#>
