Clear-Host

# Top Play Movie/Show Count
$Count = '10'

# How many Days do you want to look Back?
$Days = '30'

#Discord Webhook Prod Uri
$Uri = 'https://discord.com/api/webhooks/XXXXXX'

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

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_home_stats&grouping=1&time_range=$Days&stats_count=$Count"

#Get the Data
$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

#Split Data into Movie/Show/User
$MovieStats = $dataResult.response.data.rows | select title, guid, media_type, total_plays -Unique | where {($_.total_plays -ne $null) -and ($_.media_type -eq 'movie')}| where {($_.title -ne '')}| Sort-Object -Descending -Property total_plays | select -First $Count
$ShowStats = $dataResult.response.data.rows | select title, guid, media_type, total_plays -Unique | where {($_.total_plays -ne $null) -and ($_.media_type -eq 'episode')}| where {($_.title -ne '')}| Sort-Object -Descending -Property total_plays | select -First $Count
$UserStats = $dataResult.response.data.rows | select user, friendly_name, total_plays -Unique | where {($_.user -ne $null) -and ($_.user -ne "") -and ($_.user -ne "Local") -and ($_.total_plays -ne $null)} | Sort-Object -Descending -Property total_plays | select -First $Count

#Generate nice looking Output.
foreach ($Movie in $MovieStats) {
   $MovieStat = $Movie.guid.replace('//','').split('?').replace('com.plexapp.agents.imdb:','https://www.imdb.com/title/').replace('?lang=de','').replace('?lang=en','')[0]
   #$MovieStat = $MovieStat.replace('com.plexapp.agents.themoviedb:', 'https://www.themoviedb.org/movie/')
   $MovieList += "> "+"["+$Movie.title.Replace('½',' and half').Replace("!",'').Replace("&",'and').Replace("#",'').Replace(":",'')+"]("+$MovieStat+")"+" - Play Count: "+"**"+$Movie.total_plays+"**"+"`n"
}

foreach ($Show in $ShowStats) {
   $ShowStat=$Show.guid.replace('//','').split('/').replace('com.plexapp.agents.thetvdb:','https://www.thetvdb.com/?tab=series&id=').replace('com.plexapp.agents.themoviedb:','https://www.thetvdb.com/?tab=series&id=')[0]
   $ShowList += "> "+"["+$Show.title.Replace('é','e').Replace("'",'').Replace("!",'').Replace("&",'and').Replace("#",'').Replace(":",'').Replace("(",'').Replace(")",'')+"]("+$ShowStat+")"+" - Play Count: "+"**"+$Show.total_plays+"**"+"`n"
}

foreach ($User in $UserStats) {
   $UserList += "> " + $User.friendly_name + " - Play Count: "+"**"+$User.total_plays+"**"+"`n"
}

#using module PSDsHook to generate Content. 
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

#Preview Content
<#
$MovieContent
$ShowContent
$UserContent
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