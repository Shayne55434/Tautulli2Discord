Clear-Host

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
$dateArray = @{}
$MovieArray = @{}
$ShowArray = @{}
$MusicArray = @{}

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_by_date&grouping=1&time_range=$Days"

#Get the Data
$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

#Split Data into Movie/Show/User
$dates = $dataResult.response.data.categories
$MovieStats = $dataResult.response.data.series | where {($_.name -eq 'Movies')}
$ShowStats = $dataResult.response.data.series | where {($_.name -eq 'TV')}
$MusicStats = $dataResult.response.data.series | where {($_.name -eq 'Music')}

$i = 0
foreach ($date in $dates) {
   $dateArray.Add($i, $date)
   $i++
}

$i = 0
foreach ($movie in $MovieStats.data) {
   $MovieArray.Add($i, $movie)
   $i++
}


#Generate nice looking Output....
foreach ($Movie in $MovieStats) {
   $MovieList += "> `n"
}


#using module PSDsHook to generate Content. 
$MovieContent = @"
Top $Count played **Movies** in the last $Days Days!
$MovieList
"@

<#Preview Content
$MovieContent
#>

#Send top 10 Movies to Discord
$MoviePayload = [PSCustomObject]@{content = $MovieContent}
Invoke-RestMethod -Uri $uri -Body ($MoviePayload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'