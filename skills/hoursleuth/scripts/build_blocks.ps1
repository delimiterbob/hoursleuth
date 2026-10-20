<#
.SYNOPSIS
  Merges activity signals into time blocks, splits each block's minutes across categories,
  and writes activity_blocks.csv, activity_daily_totals.csv and report_data.json.

.EXAMPLE
  .\build_blocks.ps1 -Dir C:\work\hoursleuth-run
  .\build_blocks.ps1 -Dir C:\work\hoursleuth-run -Browser "$env:TEMP\hoursleuth\browser_visits.csv"
  .\build_blocks.ps1 -Dir C:\work\hoursleuth-run -Claude D:\laptop-export\data\activity_events.csv

.NOTES
  Inputs in -Dir:  activity_events.csv (Start,End,Source,Detail) and config.json
  Optional:        -Browser (from history.ps1), -Claude (conversation-log export from another computer)
#>
param(
  [Parameter(Mandatory)] [string]$Dir,
  [string]$Config = (Join-Path $Dir 'config.json'),
  [string]$Browser,
  [string]$Claude
)
$ErrorActionPreference = 'Stop'
$Dir = (Resolve-Path -LiteralPath $Dir).Path   # .NET file calls below need an absolute path
$cfg = [IO.File]::ReadAllText((Resolve-Path $Config)) | ConvertFrom-Json
$gap        = [int]$cfg.gapMinutes
$minDur     = [int]$cfg.minBlockMinutes
$mWeight    = [int]$cfg.meetingWeight
$adminRx    = [string]$cfg.adminPattern
$personalRx = [string]$cfg.personalPattern
$neutralRx  = [string]$cfg.neutralPattern

$fmt = 'yyyy-MM-dd HH:mm'; $ci = [Globalization.CultureInfo]::InvariantCulture
$ev = @(Import-Csv (Join-Path $Dir 'activity_events.csv') | ForEach-Object {
  $s = [datetime]::ParseExact($_.Start, $fmt, $ci)
  $e = if ($_.End) { [datetime]::ParseExact($_.End, $fmt, $ci) } else { $s }
  [pscustomobject]@{ S = $s; E = $e; Src = $_.Source; D = $_.Detail }
})
if ($Browser -and (Test-Path -LiteralPath $Browser)) {
  # One signal per (minute, host) so a redirect chain counts once
  $ev += @(Import-Csv -LiteralPath $Browser | Where-Object Host | Group-Object { $_.Time.Substring(0,16) + '|' + $_.Host } | ForEach-Object {
    $t, $h = $_.Name -split '\|', 2
    $s = [datetime]::ParseExact($t, $fmt, $ci)
    [pscustomobject]@{ S = $s; E = $s; Src = 'Browser'; D = "Browser: $h" }
  })
}
if ($Claude -and (Test-Path -LiteralPath $Claude)) {
  # Conversation log from another computer: one signal per 5-minute slot per topic,
  # otherwise a busy conversation produces hundreds of signals and outvotes meetings
  $msgs = @{}
  $mf = Join-Path (Split-Path $Claude) 'messages.csv'
  if (Test-Path -LiteralPath $mf) { Import-Csv -LiteralPath $mf | ForEach-Object { $msgs[$_.message_no] = $_.first_200_characters } }
  $ev += @(Import-Csv -LiteralPath $Claude | ForEach-Object {
    $t = [datetime]::ParseExact($_.timestamp_local.Substring(0,16), "yyyy-MM-dd'T'HH:mm", $ci)
    $slot = $t.AddMinutes(-($t.Minute % 5))
    [pscustomobject]@{ T = $t; Key = $slot.ToString($fmt) + '|' + $_.category + '|' + $_.topic_message_no; Cat = $_.category; No = $_.topic_message_no }
  } | Group-Object Key | ForEach-Object {
    $f = $_.Group[0]
    $txt = [string]$msgs[$f.No]; if ($txt.Length -gt 70) { $txt = $txt.Substring(0,70) + '...' }
    [pscustomobject]@{ S = ($_.Group | Measure-Object T -Minimum).Minimum; E = ($_.Group | Measure-Object T -Maximum).Maximum; Src = 'Claude'; D = "Claude [$($f.Cat)] msg $($f.No): $txt" }
  })
}
$ev = @($ev | Sort-Object S, E)

# Merge into blocks: same day, gap <= $gap minutes
$blocks = @(); $cur = $null
foreach ($x in $ev) {
  if ($cur -and ($x.S - $cur.E).TotalMinutes -le $gap -and $x.S.Date -eq $cur.S.Date) {
    if ($x.E -gt $cur.E) { $cur.E = $x.E }
    $cur.Items += $x
  } else {
    if ($cur) { $blocks += $cur }
    $cur = [pscustomobject]@{ S = $x.S; E = $x.E; Items = @($x) }
  }
}
if ($cur) { $blocks += $cur }

function Get-Category([string]$detail) {
  if ($detail -match $personalRx) { 'Personal' } elseif ($detail -match $adminRx) { 'Admin' } else { 'Billable' }
}

$rows = foreach ($b in $blocks) {
  $mins = [math]::Max($minDur, ($b.E - $b.S).TotalMinutes)
  $src = ($b.Items | Group-Object Src | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join '; '
  $mtg = ($b.Items | Where-Object { $_.Src -like 'Meeting*' } | ForEach-Object { $_.D }) -join ' | '
  # Summarize the most frequent non-meeting signals; browser hosts only when nothing else is there
  $pool = @($b.Items | Where-Object { $_.Src -notlike 'Meeting*' -and $_.Src -ne 'Browser' })
  if (-not $pool) { $pool = @($b.Items | Where-Object { $_.Src -notlike 'Meeting*' }) }
  $top = ($pool | ForEach-Object { $_.D -replace ' \(.*\)$','' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 4 | ForEach-Object { $_.Name }) -join ' | '

  # Every non-neutral signal votes once; a meeting votes $mWeight times in total
  $votes = [ordered]@{ 'Billable' = 0; 'Admin' = 0; 'Personal' = 0 }
  foreach ($x in $b.Items) {
    if ($x.D -match $neutralRx) { continue }
    $w = if ($x.Src -like 'Meeting*') { $mWeight } else { 1 }
    $votes[(Get-Category $x.D)] += $w
  }
  $ranked = @($votes.GetEnumerator() | Where-Object { $_.Value -gt 0 } | Sort-Object Value -Descending)
  $cat = if (-not $ranked) { 'Unclear' } elseif ($ranked.Count -eq 1) { $ranked[0].Name } else { "$($ranked[0].Name) (some $(($ranked[1..($ranked.Count-1)] | ForEach-Object Name) -join ', '))" }

  # Split minutes in proportion to votes (the majority label is for display only)
  $tv = $votes.Billable + $votes.Admin + $votes.Personal
  $mB = if ($tv) { [int][math]::Round($mins * $votes.Billable / $tv) } else { 0 }
  $mA = if ($tv) { [int][math]::Round($mins * $votes.Admin / $tv) } else { 0 }
  $mP = if ($tv) { [int]$mins - $mB - $mA } else { 0 }
  [pscustomobject]@{
    Date = $b.S.ToString('yyyy-MM-dd'); Day = $b.S.ToString('ddd', $ci); Category = $cat
    BillableMin = $mB; AdminMin = $mA; PersonalMin = $mP; UnclearMin = $(if ($tv) { 0 } else { [int]$mins })
    Start = $b.S.ToString('HH:mm'); End = $b.S.AddMinutes($mins).ToString('HH:mm')
    Minutes = [int]$mins; Signals = $b.Items.Count; Sources = $src; Meetings = $mtg; Activity = $top
  }
}
$rows = @($rows)
$rows | Export-Csv (Join-Path $Dir 'activity_blocks.csv') -NoTypeInformation -Encoding UTF8

$rows | Group-Object Date | ForEach-Object {
  $m = ($_.Group | Measure-Object Minutes -Sum).Sum
  [pscustomobject]@{ Date = $_.Name; Day = $_.Group[0].Day; Blocks = $_.Count; Hours = [math]::Round($m/60,2)
    BillableHours = [math]::Round(($_.Group | Measure-Object BillableMin -Sum).Sum/60,2)
    AdminHours    = [math]::Round(($_.Group | Measure-Object AdminMin -Sum).Sum/60,2)
    PersonalHours = [math]::Round(($_.Group | Measure-Object PersonalMin -Sum).Sum/60,2)
    UnclearHours  = [math]::Round(($_.Group | Measure-Object UnclearMin -Sum).Sum/60,2) }
} | Export-Csv (Join-Path $Dir 'activity_daily_totals.csv') -NoTypeInformation -Encoding UTF8

# JSON for the report: blocks, every event tagged with its block index, and the config it needs
$jsonEvents = for ($i = 0; $i -lt $blocks.Count; $i++) {
  foreach ($x in $blocks[$i].Items) { [ordered]@{ s = $x.S.ToString('yyyy-MM-ddTHH:mm'); e = $x.E.ToString('yyyy-MM-ddTHH:mm'); src = $x.Src; d = $x.D; b = $i } }
}
$payload = [ordered]@{
  blocks = $rows; events = @($jsonEvents); config = $cfg
  generated = (Get-Date).ToString('yyyy-MM-dd HH:mm')
}
[IO.File]::WriteAllText((Join-Path $Dir 'report_data.json'), ($payload | ConvertTo-Json -Depth 6 -Compress), (New-Object Text.UTF8Encoding $false))
"Events: $($ev.Count)  Blocks: $($blocks.Count)  Hours: $([math]::Round(($rows | Measure-Object Minutes -Sum).Sum/60,2))"
