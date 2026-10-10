# The Owner Remote for a computer: Maison Noir's admin abuse in every server, at once.
# (Made by tools/remote/build.py.) Run it in PowerShell:
#   irm https://raw.githubusercontent.com/aarokemrajsponax-cpu/robloxexperience1/claude/nice-brown-a88p9r/remote.ps1 | iex
# The first time, it asks for your Open Cloud API key (README: The Owner Remote) and keeps it,
# encrypted for your Windows account, in %APPDATA%\MaisonNoir\remote.key.
$ErrorActionPreference = 'Stop'
$Universe = '10768398256'
$Topic = 'MaisonRemote'
$Store = 'MaisonSchedule'
$Entry = 'live'
# (MAISON_REMOTE_TEST: tests/remote.py tries it against a pretend Roblox; never set it yourself.)
$Testing = [bool]$env:MAISON_REMOTE_TEST
$Api = if ($Testing -and $env:MAISON_REMOTE_API) { $env:MAISON_REMOTE_API } else { 'https://apis.roblox.com' }
$Folder = Join-Path $env:APPDATA 'MaisonNoir'
$KeyFile = Join-Path $Folder 'remote.key'
function Get-Key {
    if ($Testing -and $env:MAISON_REMOTE_KEY) { return $env:MAISON_REMOTE_KEY }
    if (Test-Path $KeyFile) {
        $secure = Get-Content $KeyFile | ConvertTo-SecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    }
    $secure = Read-Host 'Paste your Open Cloud API key (it stays on this computer)' -AsSecureString
    New-Item -ItemType Directory -Force -Path $Folder | Out-Null
    $secure | ConvertFrom-SecureString | Set-Content $KeyFile
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
# One request to Roblox: its status, what came back and the entry's version (0 if no answer).
function Invoke-Roblox([string]$Method, [string]$Uri, $Body) {
    $params = @{ Method = $Method; Uri = $Uri; Headers = @{ 'x-api-key' = (Get-Key) }; UseBasicParsing = $true }
    if ($null -ne $Body) {
        $params.Body = [Text.Encoding]::UTF8.GetBytes($Body)
        $params.ContentType = 'application/json; charset=utf-8'
    }
    try {
        $r = Invoke-WebRequest @params
        $version = $r.Headers['roblox-entry-version']
        if ($version -is [array]) { $version = $version[0] }
        $content = $r.Content
        if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
        return @{ Code = [int]$r.StatusCode; Content = [string]$content; Version = [string]$version }
    } catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        return @{ Code = $code; Content = ''; Version = '' }
    }
}
# Writes the command down in the game's own record (its list), so servers that weren't open
# carry it out when they open: read, add, write back only if nobody wrote in between.
function Write-Down($Command, [double]$At, [string]$Rid) {
    $uri = "$Api/datastores/v1/universes/$Universe/standard-datastores/datastore/entries/entry?datastoreName=$Store&entryKey=$Entry"
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    for ($try = 1; $try -le 5; $try++) {
        $got = Invoke-Roblox 'GET' $uri $null
        if ($got.Code -eq 401 -or $got.Code -eq 403) { return 'denied' }
        if ($got.Code -eq 200) {
            try { $record = $got.Content | ConvertFrom-Json } catch { return 'unreadable' }
            if ($null -eq $record -or $record -isnot [pscustomobject]) { $record = [pscustomobject]@{} }
            $mode = 'matchVersion=' + $got.Version
        } elseif ($got.Code -eq 404 -or $got.Code -eq 204) {
            $record = [pscustomobject]@{}
            $mode = 'exclusiveCreate=true'
        } else {
            Start-Sleep -Seconds $try
            continue
        }
        $log = @()
        if ($record.PSObject.Properties['log']) { $log = @($record.log | Where-Object { $_ -and ($_.at -as [double]) -gt ($now - 86400) }) }
        $log += [pscustomobject]@{ cmd = $Command; at = $At; rid = $Rid }
        if ($log.Count -gt 40) { $log = $log[($log.Count - 40)..($log.Count - 1)] }
        $record | Add-Member -NotePropertyName log -NotePropertyValue $log -Force
        $put = Invoke-Roblox 'POST' ($uri + '&' + $mode) (ConvertTo-Json -InputObject $record -Depth 20 -Compress)
        if ($put.Code -eq 200) { return 'yes' }
        if ($put.Code -eq 401 -or $put.Code -eq 403) { return 'denied' }
        Start-Sleep -Seconds $try
    }
    return 'no'
}
function Send-Command([string]$Json) {
    $obj = $Json | ConvertFrom-Json
    $rid = [guid]::NewGuid().ToString('N')
    $at = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() / 1000.0
    $obj | Add-Member -NotePropertyName rid -NotePropertyValue $rid -Force
    $obj | Add-Member -NotePropertyName at -NotePropertyValue $at -Force
    $message = ConvertTo-Json -InputObject $obj -Depth 10 -Compress
    $sent = Invoke-Roblox 'POST' "$Api/messaging-service/v1/universes/$Universe/topics/$Topic" (ConvertTo-Json -InputObject @{ message = $message } -Compress)
    if ($sent.Code -ne 200) {
        Write-Host ('  Roblox said no (' + $sent.Code + ').') -ForegroundColor Red
        Write-Host '  (401/403: the key is wrong or lacks the Messaging Service''s Publish for Maison Noir. Delete the key file to paste a new one.)' -ForegroundColor Yellow
        return
    }
    Write-Host '  Sent to every open server.' -ForegroundColor Green
    switch (Write-Down $obj $at $rid) {
        'yes' { Write-Host '  Written down: servers that open later join in too.' -ForegroundColor Green }
        'denied' { Write-Host '  Not written down: the key can''t use Maison Noir''s data stores, so a server that opens later won''t join in. Creator Hub > Open Cloud > API Keys > your key > Edit > Add API System: universe-datastores > Maison Noir > Read Entry, Create Entry, Update Entry > Save.' -ForegroundColor Yellow }
        default { Write-Host '  Not written down (Roblox''s data stores didn''t answer): a server that opens later may not join in.' -ForegroundColor Yellow }
    }
    # The remote's own test: every open server that heard it says so in the record.
    if ($obj.op -eq 'ping') {
        $uri = "$Api/datastores/v1/universes/$Universe/standard-datastores/datastore/entries/entry?datastoreName=$Store&entryKey=$Entry"
        $wait = if ($Testing -and $env:MAISON_REMOTE_PING_WAIT) { [double]$env:MAISON_REMOTE_PING_WAIT } else { 3 }
        $heard = 0
        for ($try = 1; $try -le 10; $try++) {
            Start-Sleep -Milliseconds ([int]($wait * 1000))
            $got = Invoke-Roblox 'GET' $uri $null
            if ($got.Code -eq 200) {
                try { $rec = $got.Content | ConvertFrom-Json } catch { $rec = $null }
                if ($rec -and $rec.PSObject.Properties['pong'] -and [string]$rec.pong.rid -eq $rid) { $heard = [int]$rec.pong.servers }
                if ($heard -gt 0 -and $try -ge 3) { break }
            }
        }
        if ($heard -gt 0) { Write-Host ('  The test arrived: ' + $heard + ' open server(s) heard it.') -ForegroundColor Green }
        else { Write-Host '  No server answered within 30 seconds: nobody may be playing right now (that''s fine), or the game needs publishing again.' -ForegroundColor Yellow }
    }
}
$Commands = @(
    @{ Label = '💥 Admin Abuse Night · 15 min'; Json = '{"op":"abuse","minutes":15}' }
    @{ Label = '💥 Admin Abuse Night · 30 min'; Json = '{"op":"abuse","minutes":30}' }
    @{ Label = '💥 Admin Abuse Night · 60 min'; Json = '{"op":"abuse","minutes":60}' }
    @{ Label = '🌋 MEGA ABUSE · 15 min'; Json = '{"op":"mega","minutes":15}' }
    @{ Label = '🌋 MEGA ABUSE · 30 min'; Json = '{"op":"mega","minutes":30}' }
    @{ Label = '🌋 MEGA ABUSE · 60 min'; Json = '{"op":"mega","minutes":60}' }
    @{ Label = '⏱️ Countdown, then Admin Abuse (10s)'; Json = '{"op":"countdown","id":"abuse","seconds":10}' }
    @{ Label = '⏱️ Countdown, then MEGA ABUSE (10s)'; Json = '{"op":"countdown","id":"mega","seconds":10}' }
    @{ Label = '⏱️ Countdown, then a giveaway (10s)'; Json = '{"op":"countdown","id":"giveaway","seconds":10}' }
    @{ Label = '⏱️ Countdown, then a surprise effect (10s)'; Json = '{"op":"countdown","id":"surprise","seconds":10}' }
    @{ Label = '🛑 Stop everything'; Json = '{"op":"stopAll"}' }
    @{ Label = '🚀 Rocket launch ON'; Json = '{"op":"fx","id":"launch","on":true}' }
    @{ Label = '💃 Dance party ON'; Json = '{"op":"fx","id":"dance","on":true}' }
    @{ Label = '⚡ Lightning storm ON'; Json = '{"op":"fx","id":"storm","on":true}' }
    @{ Label = '🗿 Brainrot storm ON'; Json = '{"op":"fx","id":"memeRain","on":true}' }
    @{ Label = '🎉 Confetti cannons ON'; Json = '{"op":"fx","id":"confetti","on":true}' }
    @{ Label = '💥 Shockwave ON'; Json = '{"op":"fx","id":"shockwave","on":true}' }
    @{ Label = '🌀 Spin ON'; Json = '{"op":"fx","id":"spin","on":true}' }
    @{ Label = '☄️ Meteor shower ON'; Json = '{"op":"fx","id":"meteor","on":true}' }
    @{ Label = '🕳️ Black hole ON'; Json = '{"op":"fx","id":"blackHole","on":true}' }
    @{ Label = '🌌 Aurora ON'; Json = '{"op":"fx","id":"aurora","on":true}' }
    @{ Label = '🪐 Galaxy sky ON'; Json = '{"op":"fx","id":"galaxy","on":true}' }
    @{ Label = '🛸 UFO abduction ON'; Json = '{"op":"fx","id":"ufo","on":true}' }
    @{ Label = '🌨️ Blizzard ON'; Json = '{"op":"fx","id":"blizzard","on":true}' }
    @{ Label = '🌋 Earthquake ON'; Json = '{"op":"fx","id":"earthquake","on":true}' }
    @{ Label = '🌈 Rainbow mode ON'; Json = '{"op":"fx","id":"rainbow","on":true}' }
    @{ Label = '🧼 Bubble party ON'; Json = '{"op":"fx","id":"bubbles","on":true}' }
    @{ Label = '🌊 Gold wave ON'; Json = '{"op":"fx","id":"goldWave","on":true}' }
    @{ Label = '🔥 Fire & Ice ON'; Json = '{"op":"fx","id":"fireIce","on":true}' }
    @{ Label = '🔦 Blackout ON'; Json = '{"op":"fx","id":"blackout","on":true}' }
    @{ Label = '🌪️ Tornado ON'; Json = '{"op":"fx","id":"tornado","on":true}' }
    @{ Label = '🎆 Fireworks finale ON'; Json = '{"op":"fx","id":"fireworks","on":true}' }
    @{ Label = '🗿 Titan meme ON'; Json = '{"op":"fx","id":"titan","on":true}' }
    @{ Label = '🌙 Zero gravity ON'; Json = '{"op":"fx","id":"zeroG","on":true}' }
    @{ Label = '🕺 The owner''s army ON'; Json = '{"op":"fx","id":"ownerArmy","on":true}' }
    @{ Label = '🧹 Every effect OFF'; Json = '{"op":"fxAllOff"}' }
    @{ Label = '🎃 The All Hallows'' Hunt · 15 min'; Json = '{"op":"event","id":"halloween","minutes":15}' }
    @{ Label = '🦃 The Turkey Trot · 15 min'; Json = '{"op":"event","id":"thanksgiving","minutes":15}' }
    @{ Label = '🎁 The Gift Drop · 15 min'; Json = '{"op":"event","id":"christmas","minutes":15}' }
    @{ Label = '🎆 The New Year Countdown · 15 min'; Json = '{"op":"event","id":"newYear","minutes":15}' }
    @{ Label = '💌 Sweethearts · 15 min'; Json = '{"op":"event","id":"valentine","minutes":15}' }
    @{ Label = '🍀 The Lucky Clover · 15 min'; Json = '{"op":"event","id":"stPatrick","minutes":15}' }
    @{ Label = '🥚 The Egg Hunt · 15 min'; Json = '{"op":"event","id":"easter","minutes":15}' }
    @{ Label = '🪙 Golden Hour · 15 min'; Json = '{"op":"event","id":"goldenHour","minutes":15}' }
    @{ Label = '🍀 Lucky Hour · 15 min'; Json = '{"op":"event","id":"luckyHour","minutes":15}' }
    @{ Label = '⭐ Double XP · 15 min'; Json = '{"op":"event","id":"doubleXP","minutes":15}' }
    @{ Label = '📖 The Page-Turner · 15 min'; Json = '{"op":"event","id":"pageTurner","minutes":15}' }
    @{ Label = '🦒 A Night of Giants · 15 min'; Json = '{"op":"event","id":"giants","minutes":15}' }
    @{ Label = '🐜 A Night of Small Things · 15 min'; Json = '{"op":"event","id":"tiny","minutes":15}' }
    @{ Label = '👟 The Quickstep · 15 min'; Json = '{"op":"event","id":"quickstep","minutes":15}' }
    @{ Label = '🪶 Featherlight · 15 min'; Json = '{"op":"event","id":"featherlight","minutes":15}' }
    @{ Label = '💰 Gold Rain · 15 min'; Json = '{"op":"event","id":"goldRain","minutes":15}' }
    @{ Label = '🗝️ The Treasure Hunt · 15 min'; Json = '{"op":"event","id":"treasure","minutes":15}' }
    @{ Label = '🎈 The Brainrot Parade · 15 min'; Json = '{"op":"event","id":"parade","minutes":15}' }
    @{ Label = '🪩 Disco Night · 15 min'; Json = '{"op":"event","id":"disco","minutes":15}' }
    @{ Label = '🕺 The House Party · 15 min'; Json = '{"op":"event","id":"discoHouse","minutes":15}' }
    @{ Label = '🏺 A Night of Curios · 15 min'; Json = '{"op":"event","id":"curioHour","minutes":15}' }
    @{ Label = '🎁 Giveaway · 250 Gilt'; Json = '{"op":"giveaway","amount":250}' }
    @{ Label = '🎁 Giveaway · 1000 Gilt'; Json = '{"op":"giveaway","amount":1000}' }
    @{ Label = '🎁 Giveaway · 5000 Gilt'; Json = '{"op":"giveaway","amount":5000}' }
    @{ Label = '🪙 Gilt for everyone · 100'; Json = '{"op":"giftAll","amount":100}' }
    @{ Label = '🪙 Gilt for everyone · 500'; Json = '{"op":"giftAll","amount":500}' }
    @{ Label = '🪙 Gilt for everyone · 1000'; Json = '{"op":"giftAll","amount":1000}' }
    @{ Label = '👑 The Owner''s Token'; Json = '{"op":"token"}' }
    @{ Label = '📣 ADMIN ABUSE IN 5 MINUTES! DON''T LEAVE!'; Json = '{"op":"headline","preset":1,"style":"rainbow"}' }
    @{ Label = '📣 AJKR IS IN THE SERVER! SAY HI!'; Json = '{"op":"headline","preset":2,"style":"rainbow"}' }
    @{ Label = '📣 DOUBLE GILT FOR EVERYONE RIGHT NOW!'; Json = '{"op":"headline","preset":3,"style":"rainbow"}' }
    @{ Label = '📣 GIVEAWAY TIME! STAY IN THE SERVER!'; Json = '{"op":"headline","preset":4,"style":"rainbow"}' }
    @{ Label = '📣 WHO''S READY FOR CHAOS?!'; Json = '{"op":"headline","preset":5,"style":"rainbow"}' }
    @{ Label = '📣 HOLIDAY HUNT STARTING NOW! LOOK EVERYWHERE!'; Json = '{"op":"headline","preset":6,"style":"rainbow"}' }
    @{ Label = '📣 NEW UPDATE IS LIVE! GO EXPLORE!'; Json = '{"op":"headline","preset":7,"style":"rainbow"}' }
    @{ Label = '📣 BIGGEST ADMIN ABUSE EVER, TONIGHT!'; Json = '{"op":"headline","preset":8,"style":"rainbow"}' }
    @{ Label = '📣 THANK YOU FOR PLAYING MAISON NOIR!'; Json = '{"op":"headline","preset":9,"style":"rainbow"}' }
    @{ Label = '📣 HAVING FUN? LIKE THE GAME AND TELL A FRIEND!'; Json = '{"op":"headline","preset":10,"style":"rainbow"}' }
    @{ Label = '🌙 Time of day: Midnight'; Json = '{"op":"clock","id":"midnight"}' }
    @{ Label = '🌄 Time of day: Dawn'; Json = '{"op":"clock","id":"dawn"}' }
    @{ Label = '☀️ Time of day: Noon'; Json = '{"op":"clock","id":"noon"}' }
    @{ Label = '🌇 Time of day: Sunset'; Json = '{"op":"clock","id":"sunset"}' }
    @{ Label = '🔔 Test the remote (nothing happens in the game)'; Json = '{"op":"ping"}' }
)
$Nights = @(
    @{ Id = 'classic'; Name = 'THE CLASSIC' }
    @{ Id = 'midasHeist'; Name = 'THE MIDAS HEIST' }
    @{ Id = 'cosmicTakeover'; Name = 'COSMIC TAKEOVER' }
    @{ Id = 'brainrotApocalypse'; Name = 'BRAINROT APOCALYPSE' }
    @{ Id = 'hotDisco'; Name = 'HOT HOT DISCO' }
    @{ Id = 'frostbiteFrenzy'; Name = 'FROSTBITE FRENZY' }
    @{ Id = 'candyChaos'; Name = 'CANDY CHAOS' }
    @{ Id = 'neonOverdrive'; Name = 'NEON OVERDRIVE' }
    @{ Id = 'deepDive'; Name = 'THE DEEP DIVE' }
    @{ Id = 'thunderPalace'; Name = 'THUNDER PALACE' }
    @{ Id = 'meteorMadness'; Name = 'METEOR MADNESS' }
    @{ Id = 'singularity'; Name = 'THE SINGULARITY' }
    @{ Id = 'alienInvasion'; Name = 'ALIEN INVASION' }
    @{ Id = 'royalBall'; Name = 'THE ROYAL BALL' }
    @{ Id = 'aboveTheClouds'; Name = 'ABOVE THE CLOUDS' }
    @{ Id = 'jungleRumble'; Name = 'JUNGLE RUMBLE' }
    @{ Id = 'pharaohsGold'; Name = 'THE PHARAOH''S GOLD' }
    @{ Id = 'cherryBlossom'; Name = 'CHERRY BLOSSOM NIGHT' }
    @{ Id = 'retrowave'; Name = 'RETROWAVE ''86' }
    @{ Id = 'theGlitch'; Name = 'THE GLITCH' }
    @{ Id = 'rocketNight'; Name = 'ROCKET NIGHT' }
    @{ Id = 'zeroGravityGala'; Name = 'ZERO GRAVITY GALA' }
    @{ Id = 'confettiCannonade'; Name = 'THE CONFETTI CANNONADE' }
    @{ Id = 'titanShowdown'; Name = 'TITAN SHOWDOWN' }
    @{ Id = 'lightsOutParty'; Name = 'LIGHTS OUT PARTY' }
    @{ Id = 'midnightAgent'; Name = 'MIDNIGHT AGENT' }
    @{ Id = 'tornadoAlley'; Name = 'TORNADO ALLEY' }
    @{ Id = 'goldRushHour'; Name = 'GOLD RUSH HOUR' }
    @{ Id = 'fireAndIce'; Name = 'FIRE & ICE' }
    @{ Id = 'bubbleMania'; Name = 'BUBBLE MANIA' }
    @{ Id = 'rainbowRiot'; Name = 'RAINBOW RIOT' }
    @{ Id = 'memeLords'; Name = 'RISE OF THE MEME LORDS' }
    @{ Id = 'supernova'; Name = 'SUPERNOVA' }
    @{ Id = 'endOfTheWorld'; Name = 'END OF THE WORLD PARTY' }
    @{ Id = 'galaxyBrain'; Name = 'GALAXY BRAIN' }
    @{ Id = 'wizardsTower'; Name = 'THE WIZARD''S TOWER' }
    @{ Id = 'kingOfTheHouse'; Name = 'KING OF THE HOUSE' }
    @{ Id = 'ajkrsArmy'; Name = 'AJKR''S ARMY' }
    @{ Id = 'colossusRises'; Name = 'THE COLOSSUS RISES' }
    @{ Id = 'arcadeMode'; Name = 'ARCADE MODE' }
    @{ Id = 'stormChasers'; Name = 'STORM CHASERS' }
    @{ Id = 'greenRoom'; Name = 'THE GREEN ROOM' }
    @{ Id = 'vipLounge'; Name = 'THE VIP LOUNGE' }
    @{ Id = 'carnivalNight'; Name = 'CARNIVAL NIGHT' }
    @{ Id = 'hyperdrive'; Name = 'HYPERDRIVE' }
    @{ Id = 'volcanoNight'; Name = 'VOLCANO NIGHT' }
    @{ Id = 'snowGlobe'; Name = 'THE SNOW GLOBE' }
    @{ Id = 'dreamland'; Name = 'DREAMLAND' }
    @{ Id = 'finalBoss'; Name = 'THE FINAL BOSS' }
    @{ Id = 'theHack'; Name = 'THE HACK' }
    @{ Id = 'goldenAge'; Name = 'THE GOLDEN AGE' }
    @{ Id = 'chaosTheory'; Name = 'CHAOS THEORY' }
    @{ Id = 'masquerade'; Name = 'MIDNIGHT MASQUERADE' }
    @{ Id = 'palmBeach'; Name = 'PALM BEACH NIGHTS' }
    @{ Id = 'wildWest'; Name = 'WILD WEST SHOWDOWN' }
)
# Admin Abuse or Mega Abuse: which night (Enter for a surprise: the same in every server either way).
function Add-Night([string]$Json, [string]$Asked) {
    $obj = $Json | ConvertFrom-Json
    $abuse = $obj.op -eq 'abuse' -or $obj.op -eq 'mega' -or ($obj.op -eq 'countdown' -and ($obj.id -eq 'abuse' -or $obj.id -eq 'mega'))
    if (-not $abuse -or -not $Asked) { return $Json }
    $n = 0
    $pick = $null
    if ([int]::TryParse($Asked, [ref]$n) -and $n -ge 1 -and $n -le $Nights.Count) { $pick = $Nights[$n - 1] }
    else { $pick = $Nights | Where-Object { $_.Name -like ('*' + $Asked + '*') } | Select-Object -First 1 }
    if (-not $pick) { return $Json }
    $obj | Add-Member -NotePropertyName night -NotePropertyValue $pick.Id -Force
    return ($obj | ConvertTo-Json -Compress)
}
if ($Testing) { return }
[Console]::OutputEncoding = [Text.Encoding]::UTF8
while ($true) {
    Write-Host ''
    Write-Host '  MAISON NOIR  ·  THE OWNER REMOTE  ·  every server, at once' -ForegroundColor Yellow
    for ($i = 0; $i -lt $Commands.Count; $i++) { Write-Host ('  {0,3}  {1}' -f ($i + 1), $Commands[$i].Label) }
    Write-Host '    h  A headline in your own words'
    Write-Host '    q  Quit'
    $choice = Read-Host '  Choose'
    if ($choice -eq 'q') { break }
    if ($choice -eq 'h') {
        $words = Read-Host '  Your headline (140 letters; Roblox''s filter checks it)'
        if ($words) { Send-Command (@{ op = 'headline'; text = $words.Substring(0, [Math]::Min(140, $words.Length)); style = 'rainbow' } | ConvertTo-Json -Compress) }
        continue
    }
    $n = 0
    if ([int]::TryParse($choice, [ref]$n) -and $n -ge 1 -and $n -le $Commands.Count) {
        Write-Host ('  ' + $Commands[$n - 1].Label)
        $json = $Commands[$n - 1].Json
        if ($json -match '\"op\":\"(abuse|mega|countdown)\"') {
            for ($i = 0; $i -lt $Nights.Count; $i++) { Write-Host ('  {0,3}  {1}' -f ($i + 1), $Nights[$i].Name) -ForegroundColor DarkYellow }
            $asked = Read-Host '  Which night? (Enter for a surprise, or its number or name)'
            $json = Add-Night $json $asked
        }
        Send-Command $json
    }
}
