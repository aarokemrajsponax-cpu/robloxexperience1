# The Owner Remote for a computer: Maison Noir's admin abuse in every server, at once.
# (Made by tools/remote/build.py.) Run it in PowerShell:
#   irm https://raw.githubusercontent.com/aarokemrajsponax-cpu/robloxexperience1/claude/nice-brown-a88p9r/remote.ps1 | iex
# The first time, it asks for your Open Cloud API key (README: The Owner Remote) and keeps it,
# encrypted for your Windows account, in %APPDATA%\MaisonNoir\remote.key.
$ErrorActionPreference = 'Stop'
$Universe = '10768398256'
$Topic = 'MaisonRemote'
$Folder = Join-Path $env:APPDATA 'MaisonNoir'
$KeyFile = Join-Path $Folder 'remote.key'
function Get-Key {
    if (Test-Path $KeyFile) {
        $secure = Get-Content $KeyFile | ConvertTo-SecureString
        return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    }
    $secure = Read-Host 'Paste your Open Cloud API key (it stays on this computer)' -AsSecureString
    New-Item -ItemType Directory -Force -Path $Folder | Out-Null
    $secure | ConvertFrom-SecureString | Set-Content $KeyFile
    return [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}
function Send-Command([string]$Json) {
    $body = @{ message = $Json } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod -Method Post -Uri "https://apis.roblox.com/messaging-service/v1/universes/$Universe/topics/$Topic" -Headers @{ 'x-api-key' = (Get-Key) } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
        Write-Host '  Sent to every server.' -ForegroundColor Green
    } catch {
        Write-Host ('  Roblox said no: ' + $_.Exception.Message) -ForegroundColor Red
        Write-Host '  (401/403: the key is wrong or lacks the Messaging Service''s Publish for Maison Noir. Delete the key file to paste a new one.)' -ForegroundColor Yellow
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
    @{ Label = '🚀 Rocket launch'; Json = '{"op":"fx","id":"launch"}' }
    @{ Label = '💃 Dance party'; Json = '{"op":"fx","id":"dance"}' }
    @{ Label = '⚡ Lightning storm'; Json = '{"op":"fx","id":"storm"}' }
    @{ Label = '🗿 Brainrot storm'; Json = '{"op":"fx","id":"memeRain"}' }
    @{ Label = '🎉 Confetti cannons'; Json = '{"op":"fx","id":"confetti"}' }
    @{ Label = '💥 Shockwave'; Json = '{"op":"fx","id":"shockwave"}' }
    @{ Label = '🌀 Spin'; Json = '{"op":"fx","id":"spin"}' }
    @{ Label = '☄️ Meteor shower'; Json = '{"op":"fx","id":"meteor"}' }
    @{ Label = '🕳️ Black hole'; Json = '{"op":"fx","id":"blackHole"}' }
    @{ Label = '🌌 Aurora'; Json = '{"op":"fx","id":"aurora"}' }
    @{ Label = '🪐 Galaxy sky'; Json = '{"op":"fx","id":"galaxy"}' }
    @{ Label = '🛸 UFO abduction'; Json = '{"op":"fx","id":"ufo"}' }
    @{ Label = '🌨️ Blizzard'; Json = '{"op":"fx","id":"blizzard"}' }
    @{ Label = '🌋 Earthquake'; Json = '{"op":"fx","id":"earthquake"}' }
    @{ Label = '🌈 Rainbow mode'; Json = '{"op":"fx","id":"rainbow"}' }
    @{ Label = '🧼 Bubble party'; Json = '{"op":"fx","id":"bubbles"}' }
    @{ Label = '🌊 Gold wave'; Json = '{"op":"fx","id":"goldWave"}' }
    @{ Label = '🔥 Fire & Ice'; Json = '{"op":"fx","id":"fireIce"}' }
    @{ Label = '🔦 Blackout'; Json = '{"op":"fx","id":"blackout"}' }
    @{ Label = '🌪️ Tornado'; Json = '{"op":"fx","id":"tornado"}' }
    @{ Label = '🎆 Fireworks finale'; Json = '{"op":"fx","id":"fireworks"}' }
    @{ Label = '🗿 Titan meme'; Json = '{"op":"fx","id":"titan"}' }
    @{ Label = '🌙 Zero gravity'; Json = '{"op":"fx","id":"zeroG"}' }
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
    @{ Label = '📣 THE OWNER IS IN THE SERVER! SAY HI!'; Json = '{"op":"headline","preset":2,"style":"rainbow"}' }
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
)
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
        Send-Command $Commands[$n - 1].Json
    }
}
