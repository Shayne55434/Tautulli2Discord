Clear-Host

# Discord Webhook Prod Uri
$Uri = 'https://discord.com/api/webhooks/XXXXXX'

# Tautulli Url with port
$URL = "XXXXXX"

# Tautulli Api Key
$apiKey='XXXXXX'

# Libraries to exclude
$ExcludedLibraries = @('Photos', 'Live TV', 'Fitness', 'Audiobooks')

<############################################################

 Do NOT edit lines below unless you know what you are doing!

############################################################>

# Clear previously used variables
$MovieList = $null
$ShowList = $null
$CountdataResultMovie = $null
$CountdataResultShow = $null

#Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_libraries_table"

# Create empty object
$objTemplate = New-Object psobject
$objTemplate | Add-Member -MemberType NoteProperty -Name Library -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name Type -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name Count -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name SeasonAlbumCount -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name EpisodeTrackCount -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name Size -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name Format -Value $null
$objResult = @()

#Get the Data Count
$CountdataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$Sections = $CountdataResult.response.data.data | Select section_id, section_name, section_type, count, parent_count, child_count | Where-Object -Property section_name -notin ($ExcludedLibraries)

foreach ($Section in $Sections){
   $SizeResult = (Invoke-RestMethod -Method Get -Uri "$URL/api/v2?apikey=$apiKey&cmd=get_library_media_info&section_id=$($Section.section_id)").response.data.total_file_size
   
   if ($SizeResult -ge '1000000000000') {
      $Format = 'Tb'
      $SizeResult = [math]::round($SizeResult /1Tb, 2)
   }
   else{
      $Format = 'Gb'
      $SizeResult = [math]::round($SizeResult /1Gb, 2)
   }
   
   #Fill Temp object with current section data
   $objTemp = $objTemplate | Select-Object *
   $objTemp.Library = $Section.section_name
   $objTemp.Type = $Section.section_type
   $objTemp.Count = $Section.count
   $objTemp.SeasonAlbumCount= $Section.parent_count
   $objTemp.EpisodeTrackCount = $Section.child_count
   $objTemp.Size = $SizeResult
   $objTemp.Format = $Format
   
   #Add section data results to final object
   $objResult += $objTemp
}

$objResult = $objResult | Sort-Object -Property Library, Type
$CountdataResultShow = $null

foreach($Library in $objResult) {
   if ($Library.Type -eq 'movie') {
      $CountdataResultShow += "> $($Library.Library) - **$($Library.count)** movies. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'show') {
      $CountdataResultShow += "> $($Library.Library) - **$($Library.count)** shows, **$($Library.SeasonAlbumCount)** seasons, **$($Library.EpisodeTrackCount)** episodes. ($($Library.Size)$($Library.Format))`n"
   }
   elseif ($Library.Type -eq 'artist') {
      $CountdataResultShow += "> $($Library.Library) - **$($Library.count)** artists, **$($Library.SeasonAlbumCount)** albums, **$($Library.EpisodeTrackCount)** tracks. ($($Library.Size)$($Library.Format))`n"
   }
}

#Generate Content. 
$Content = @"
**Library stats:**
$CountdataResultShow
"@

<#Preview Content
$Content
#>

#Send to Discord
$payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'