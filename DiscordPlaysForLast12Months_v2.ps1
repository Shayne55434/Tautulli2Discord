Clear-Host

# Sending Files to Discord currently only works with powershell 6+
# Install relevant PS version from here: https://github.com/PowerShell/PowerShell/releases
# This script relies on another: DiscordSendFile.ps1

# Discord Webhook Uri
$Uri = "https://discordapp.com/api/webhooks/XXXXXX"

# Tautulli URL with port
$URL = "XXXXXX"

# Tautulli API Key
$apiKey='XXXXXX'

# Path to where the chart image should be saved and sent from
$ImagePath = "C:\temp\MonthlyStats.png"

# PowerShell variables
$PSCore = "C:\Program Files\PowerShell\7-preview\pwsh.exe"
$SendScriptPath = "C:\Users\Shayne\Google Drive\Plex Stuff\PowerShell\DiscordSendFile.ps1"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

function CreateChart {
# Chart creator

[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

# chart object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 1200
   $chart1.Height = 500
   $chart1.BackColor = [System.Drawing.Color]::White

# title
   [void]$chart1.Titles.Add("Monthly Plays!")
   $chart1.Titles[0].Font = "Calibri,18pt"
   $chart1.Titles[0].Alignment = "topCenter"

# chart area
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Number of Plays"
   $chartarea.AxisX.Title = "Month"
   $chartarea.AxisY.Interval = 50
   $chartarea.AxisX.Interval = 1
   $chart1.ChartAreas.Add($chartarea)

# legend
   $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
   $legend.name = "Legend1"
   $chart1.Legends.Add($legend)

# data series
   [void]$chart1.Series.Add("Month")
   $chart1.Series["Month"].ChartType = "Column"
   $chart1.Series["Month"].BorderWidth  = 3
   $chart1.Series["Month"].IsVisibleInLegend = $false
   $chart1.Series["Month"].chartarea = "ChartArea1"
   $chart1.Series["Month"].Legend = "Legend1"
   $chart1.Series["Month"].color = "#90b19c"
   $objResult.Month | ForEach-Object {$chart1.Series["Month"].Points.addxy($_, $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("MoviePlays")
   $chart1.Series["MoviePlays"].ChartType = "Column"
   $chart1.Series["MoviePlays"].BorderWidth  = 3
   $chart1.Series["MoviePlays"].IsVisibleInLegend = $true
   $chart1.Series["MoviePlays"].chartarea = "ChartArea1"
   $chart1.Series["MoviePlays"].Legend = "Legend1"
   $chart1.Series["MoviePlays"].color = "#5B9BD5"
   $objResult.MoviePlays | ForEach-Object {$chart1.Series["MoviePlays"].Points.addxy("MoviePlays", $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("TVPlays")
   $chart1.Series["TVPlays"].ChartType = "Column"
   $chart1.Series["TVPlays"].BorderWidth  = 3
   $chart1.Series["TVPlays"].IsVisibleInLegend = $true
   $chart1.Series["TVPlays"].chartarea = "ChartArea1"
   $chart1.Series["TVPlays"].Legend = "Legend1"
   $chart1.Series["TVPlays"].color = "#ED7D31"
   $objResult.TVPlays | ForEach-Object {$chart1.Series["TVPlays"].Points.addxy("TVPlays", $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("MusicPlays")
   $chart1.Series["MusicPlays"].ChartType = "Column"
   $chart1.Series["MusicPlays"].BorderWidth  = 3
   $chart1.Series["MusicPlays"].IsVisibleInLegend = $true
   $chart1.Series["MusicPlays"].chartarea = "ChartArea1"
   $chart1.Series["MusicPlays"].Legend = "Legend1"
   $chart1.Series["MusicPlays"].color = "#A5A5A5"
   $objResult.MusicPlays | ForEach-Object {$chart1.Series["MusicPlays"].Points.addxy("MusicPlays", $_) } | Out-Null
# data series
   [void]$chart1.Series.Add("TotalPlays")
   $chart1.Series["TotalPlays"].ChartType = "Column"
   $chart1.Series["TotalPlays"].BorderWidth  = 3
   $chart1.Series["TotalPlays"].IsVisibleInLegend = $true
   $chart1.Series["TotalPlays"].chartarea = "ChartArea1"
   $chart1.Series["TotalPlays"].Legend = "Legend1"
   $chart1.Series["TotalPlays"].color = "#FFC000"
   $objResult.TotalPlays | ForEach-Object {$chart1.Series["TotalPlays"].Points.addxy("TotalPlays", $_) } | Out-Null
# save chart
   $chart1.SaveImage($ImagePath,"png")
}

# Complete API URL
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=get_plays_per_month"

# Build our empty object
$objTemplate = New-Object psobject
$objTemplate | Add-Member -MemberType NoteProperty -Name Month -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name MoviePlays -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name TVPlays -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name MusicPlays -Value $null
$objTemplate | Add-Member -MemberType NoteProperty -Name TotalPlays -Value $null
$objResult = @()

# Get relevant data from the API
$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL
$months = $dataResult.response.data.categories
$Movieplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Movies').data
$TVplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'TV').data
$Musicplays = ($dataResult.response.data.series | Where-Object -Property name -eq 'Music').data
$i = 0

# Fill the temp object with current section data
foreach($month in $months) {
   $objTemp = $objTemplate | Select-Object *
   $objTemp.Month = $month
   $objTemp.MoviePlays = $Movieplays[$i]
   $objTemp.TVPlays = $TVplays[$i]
   $objTemp.MusicPlays = $Musicplays[$i]
   $objTemp.TotalPlays = $Movieplays[$i] + $TVplays[$i] + $Musicplays[$i]
   
   # Add section data results to final object
   $objResult += $objTemp
   
   $i++
}

# Remove any lines with all 0s
$objResult = $objResult | Where-Object -Property TotalPlays -gt 0

# Create Chart (Call function)
CreateChart

# Convert the object to a string
$stringResult = $objResult | FT | Out-String

<# Preview the data
$stringResult
#>

$Content = @"
**Monthly Plays:**
```
$stringResult```
"@

# Create Payload and send to Discord
$Payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($Payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'

# Call $SendScriptPath to send the newly created image to Discord via PS v7
& $PSCore -NoLogo -NonInteractive -ExecutionPolicy Bypass -File $SendScriptPath -FilePath $ImagePath -WebhookUrl $Uri | Out-Null