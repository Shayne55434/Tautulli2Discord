Clear-Host

# Discord Webhook Prod Uri
$Uri = "https://discordapp.com/api/webhooks/XXXXXX"

# Tautulli URL with port
$URL = "XXXXXX"

# Tautulli API Key
$apiKey='XXXXXX'

# Enter a path to save the results as an Excel file
$ExcelPath = "C:\temp\test.xlsx"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

# Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_per_month"

$objTemplate = New-Object psobject
$objTemplate | Add-Member -MemberType NoteProperty -Name Month -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name MoviePlays -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name TVPlays -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name MusicPlays -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name TotalPlays -Value $null
$objResult = @()

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$months = $dataResult.response.data.categories
$Movieplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Movies').data
$TVplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'TV').data
$Musicplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Music').data
$i = 0

foreach($month in $months) {
   #Fill Temp object with current section data
   $objTemp = $objTemplate | Select-Object *
   $objTemp.Month = $month
   $objTemp.MoviePlays = $Movieplays[$i]
   $objTemp.TVPlays = $TVplays[$i]
   $objTemp.MusicPlays= $Musicplays[$i]
   $objTemp.TotalPlays= $Movieplays[$i] + $TVplays[$i] + $Musicplays[$i]
   
   #Add section data results to final object
   $objResult += $objTemp
   
   $i++
}

# Remove any lines with all 0s
$objResult = $objResult | Where-Object -Property TotalPlays -gt 0

# Convert the object to a string
$stringResult = $objResult | FT | Out-String
$stringResult = '```' + $stringResult + '```'

<# Preview the data
$stringResult
#>

$Content = @"
**Monthly Plays:**
$stringResult
"@

# Create Paylaod
$Payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'
