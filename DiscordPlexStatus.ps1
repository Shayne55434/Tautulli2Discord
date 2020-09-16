Clear-Host

#Discord Webhook Prod Uri
$Uri = "https://discordapp.com/api/webhooks/XXXXXX"

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 <# using TLS 1.2 is vitally important #>
$status = $null
$searchClass = "status font-large"
$myURI = "https://status.plex.tv/"
$req = Invoke-Webrequest -URI $myURI #-UseBasicParsing
$classes = $req.ParsedHtml.getElementsByClassName($searchClass)

foreach ($class in $classes) {
   $status += ($class.innerhtml).Trim()
}

#Generate Content. 
$Content = @"
**Current status of plex.tv:**
> $status
"@

<# Preview the content
$Content
#>

$payload = [PSCustomObject]@{content = $Content}
Invoke-RestMethod -Uri $uri -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'Application/Json'