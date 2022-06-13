Clear-Host

<############################################################
Note - For this script to send files to Discord, you must
       have PowerShell 6 or newer installed and have
       "PSCoreFilePath" configured in config.json Install
       relevant PS version from here:
       https://github.com/PowerShell/PowerShell/releases
#############################################################>

# Enter the path to the config file for Tautulli and Discord
[string]$strPathToConfig = "$PSScriptRoot\config.json"

# Script name MUST match what is in config.json under "ScriptSettings"
[string]$strScriptName = "PlexPlayStats"

# Path to where the chart image should be saved and sent from
[string]$strImagePath = "$PSScriptRoot\MonthlyStats.png"

# PowerShell variables
[string]$strSendScriptFilePath = "$PSScriptRoot\SendFileToDiscord.ps1"

<############################################################
Do NOT edit lines below unless you know what you are doing!
############################################################>

# Define the functions to be used
function Push-ObjectToDiscord {
   [CmdletBinding()]
   param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$strDiscordWebhook,
      
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [object]$objPayload
   )
   try {
      $null = Invoke-RestMethod -Method Post -Uri $strDiscordWebhook -Body $objPayload -ContentType 'Application/Json'
      Start-Sleep -Seconds 1
   }
   catch {
      Write-Host "Unable to send to Discord. $($_)" -ForegroundColor Red
      Write-Host $objPayload
   }
}
function New-ChartImage {
   # Chart Creator
   $null = [Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")
   
   # Chart Object
   $chart1 = New-object System.Windows.Forms.DataVisualization.Charting.Chart
   $chart1.Width = 1200
   $chart1.Height = 500
   $chart1.BackColor = [System.Drawing.Color]::White
   
   # Title
   $null = $chart1.Titles.Add("Monthly Plays!")
   $chart1.Titles[0].Font = "Calibri,18pt"
   $chart1.Titles[0].Alignment = "topCenter"
   
   # Chart Area
   $chartarea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
   $chartarea.Name = "ChartArea1"
   $chartarea.AxisY.Title = "Number of Plays"
   $chartarea.AxisX.Title = "Month"
   $chartarea.AxisY.Interval = 50
   $chartarea.AxisX.Interval = 1
   $chart1.ChartAreas.Add($chartarea)
   
   # Legend
   $legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
   $legend.name = "Legend1"
   $chart1.Legends.Add($legend)
   
   # Data Series - Month
   $null = $chart1.Series.Add("Month")
   $chart1.Series["Month"].ChartType = "Column"
   $chart1.Series["Month"].BorderWidth  = 3
   $chart1.Series["Month"].IsVisibleInLegend = $false
   $chart1.Series["Month"].chartarea = "ChartArea1"
   $chart1.Series["Month"].Legend = "Legend1"
   $chart1.Series["Month"].color = "#90b19c"
   $null = $arrPlaysPerMonth.Month | ForEach-Object {$chart1.Series["Month"].Points.addxy($_, $_) }
   
   # Data Series - Each Media Type
   [hashtable]$htbMediaTypeColors = @{
      TV = "#00CCFF"
      Movies = "#FFC230"
      Music = "#009253"
      "Live TV" = "#A5A5A5"
   }
   foreach ($MediaType in $arrMediaTypes) {
      $null = $chart1.Series.Add($MediaType)
      $chart1.Series[$($MediaType)].ChartType = "Column"
      $chart1.Series[$($MediaType)].BorderWidth  = 3
      $chart1.Series[$($MediaType)].IsVisibleInLegend = $true
      $chart1.Series[$($MediaType)].chartarea = "ChartArea1"
      $chart1.Series[$($MediaType)].Legend = "Legend1"
      $chart1.Series[$($MediaType)].color = $htbMediaTypeColors.$MediaType
      $null = $arrPlaysPerMonth.$MediaType | ForEach-Object {$chart1.Series[$($MediaType)].Points.addxy($MediaType, $_) }
   }
   
   # Data Series - Total
   $null = $chart1.Series.Add("Total")
   $chart1.Series["Total"].ChartType = "Column"
   $chart1.Series["Total"].BorderWidth  = 3
   $chart1.Series["Total"].IsVisibleInLegend = $true
   $chart1.Series["Total"].chartarea = "ChartArea1"
   $chart1.Series["Total"].Legend = "Legend1"
   $chart1.Series["Total"].color = " #E00000"
   $null = $arrPlaysPerMonth.Total | ForEach-Object {$chart1.Series["Total"].Points.addxy("Total", $_) }
   
   # Save Chart as Image
   $chart1.SaveImage($strImagePath,"png")
}

# Parse the config file and assign variables
[object]$objConfig = Get-Content -Path $strPathToConfig -Raw | ConvertFrom-Json
[string]$strDiscordWebhook = $objConfig.ScriptSettings.$strScriptName.Webhook
[string]$strPSCoreFilePath = $objConfig.ScriptSettings.$strScriptName.PSCoreFilePath
[array]$arrMediaTypes = $objConfig.ScriptSettings.$strScriptName.MediaTypes
[string]$strTautulliURL = $objConfig.Tautulli.URL
[string]$strTautulliAPIKey = $objConfig.Tautulli.APIKey
[object]$objPlaysPerMonth = Invoke-RestMethod -Method Get -Uri "$strTautulliURL/api/v2?apikey=$strTautulliAPIKey&cmd=get_plays_per_month"
[array]$arrLast12Months = $objPlaysPerMonth.response.data.categories
[array]$arrTopPlaysPerMonth = $objPlaysPerMonth.response.data.series | Where-Object -Property name -in $arrMediaTypes

# Loop through each Month and MediaType
$i = 0
[System.Collections.ArrayList]$arrPlaysPerMonth = @()
foreach($month in $arrLast12Months) {
   [hashtable]$htbCurrentMonth = @{
      Month = $month
   }
   
   [int]$intMonthTotal = 0
   foreach ($MediaType in $arrTopPlaysPerMonth) {
      [hashtable]$htbCurrentMonthPlayStats = @{
         $MediaType.Name = $MediaType.data[$i]
      }
      $intMonthTotal += $MediaType.data[$i]
      $htbCurrentMonth += $htbCurrentMonthPlayStats
   }
   $htbCurrentMonth += @{Total = $intMonthTotal}
   
   $null = $arrPlaysPerMonth.Add($htbCurrentMonth)
   $i++
}

if ($objConfig.ScriptSettings.$strScriptName.RemoveMonthsWithZeroPlays) {
   # Remove any lines with all 0s
   $arrPlaysPerMonth = $arrPlaysPerMonth | Where-Object -Property Total -gt 0
}

# Create Chart (Call function)
New-ChartImage

# Convert results to string and send to Discord
[array]$arrProperties = @('Month') + $arrMediaTypes + @('Total') # This is so the final table is in a logical ordering.
[string]$strBody = $arrPlaysPerMonth | ForEach-Object {[PSCustomObject]$_} | Format-Table -AutoSize -Property @($arrProperties) | Out-String
[object]$objPayload = @{
   content = @"
**Monthly Plays:**
``````
$strBody
``````
"@
} | ConvertTo-Json -Depth 4
Push-ObjectToDiscord -strDiscordWebhook $strDiscordWebhook -objPayload $objPayload

if (Test-Path $strPSCoreFilePath) {
   # Call $strSendScriptFilePath to send the newly created image to Discord via PS v6+
   $null = & $strPSCoreFilePath -NoLogo -NonInteractive -ExecutionPolicy Bypass -File $strSendScriptFilePath -FilePath $strImagePath -WebhookUrl $strDiscordWebhook
}