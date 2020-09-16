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
$Uri = "https://discord.com/api/webhooks/732620980601487454/oYXX6zIrtgyFORlRPRYrCW8c9cyhTTbLCicS2J-6BHI3cLcv97pHya2EerfBipqycz2A"

#Tautulli URL with port
$URL = "192.168.0.32:8181"

#Tautulli API Key
$apiKey='0c14b635454d47ea9ac279269d96c169'

<############################################################

Do NOT edit lines below unless you know what you are doing!

############################################################>

$query = "
SELECT DISTINCT
artist,
track_name,
count(*) AS plays
FROM (
	SELECT
	CASE
	   WHEN friendly_name IS NULL THEN username
	   ELSE friendly_name
	END AS friendly_name,
	grandparent_title AS artist,
	parent_title AS album,
	title AS track_name
	FROM session_history
	LEFT JOIN session_history_metadata
		ON session_history_metadata.id = session_history.id
	LEFT OUTER JOIN users
		ON session_history.user_id = users.user_id
	WHERE session_history.media_type = 'track'
	AND datetime(session_history.stopped, 'unixepoch', 'localtime') >= datetime('now', '-$Days days', 'localtime')
) AS t
GROUP BY track_name, artist
ORDER BY count(*) DESC, track_name
"

#Complete API URL for SQL querying
$apiURL = "$URL/api/v2?apikey=$apiKey&cmd=sql&query=" + $query

$dataResult = Invoke-RestMethod -Method Get -Uri $apiURL

$TopTracks = $dataResult.response.data | Sort-Object -Property plays -Descending | Select-Object -Property artist, track_name, plays -First $count

$TopTracks