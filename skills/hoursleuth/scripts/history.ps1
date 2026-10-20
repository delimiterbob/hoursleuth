<#
.SYNOPSIS
  Extracts browser visits (time, browser, host, title) from copies of Chromium History files.

.EXAMPLE
  .\history.ps1 -Out "$env:TEMP\hoursleuth\browser_visits.csv" -StartDate 2026-03-02
  .\history.ps1 -Out visits.csv -StartDate 2026-03-02 -HistoryFiles @{ Chrome = 'C:\path\to\History' }

.NOTES
  - Never reads the live file: each History file is copied next to -Out first.
  - Write -Out to a scratch/temp folder, not your project: the CSV lists every page title.
  - Uses winsqlite3.dll, which ships with Windows 10/11. No installs needed.
#>
param(
  [Parameter(Mandatory)] [string]$Out,
  [Parameter(Mandatory)] [datetime]$StartDate,               # local date the range starts (midnight)
  [string]$TimeZone = 'Eastern Standard Time',                # Windows time zone ID; handles DST
  [hashtable]$HistoryFiles                                     # label -> History path; defaults below
)

# ---- CONFIG: only list profiles used for work ----
if (-not $HistoryFiles) {
  $HistoryFiles = @{
    'Chrome' = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
    'Edge'   = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
  }
}
# ---------------------------------------------------

$src = @"
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class HsSqlite {
  [DllImport("winsqlite3.dll", CharSet=CharSet.Ansi)] static extern int sqlite3_open_v2(string f, out IntPtr db, int flags, IntPtr vfs);
  [DllImport("winsqlite3.dll")] static extern int sqlite3_prepare_v2(IntPtr db, byte[] sql, int n, out IntPtr st, IntPtr tail);
  [DllImport("winsqlite3.dll")] static extern int sqlite3_step(IntPtr st);
  [DllImport("winsqlite3.dll")] static extern int sqlite3_column_count(IntPtr st);
  [DllImport("winsqlite3.dll")] static extern IntPtr sqlite3_column_text(IntPtr st, int i);
  [DllImport("winsqlite3.dll")] static extern int sqlite3_finalize(IntPtr st);
  [DllImport("winsqlite3.dll")] static extern int sqlite3_close(IntPtr db);
  [DllImport("winsqlite3.dll")] static extern IntPtr sqlite3_errmsg(IntPtr db);
  static string U8(IntPtr p){ if(p==IntPtr.Zero) return ""; int n=0; while(Marshal.ReadByte(p,n)!=0) n++; byte[] b=new byte[n]; Marshal.Copy(p,b,0,n); return System.Text.Encoding.UTF8.GetString(b); }
  public static List<string[]> Query(string file, string sql){
    IntPtr db; if(sqlite3_open_v2(file, out db, 1, IntPtr.Zero)!=0) throw new Exception("open failed: " + file);
    IntPtr st; byte[] q=System.Text.Encoding.UTF8.GetBytes(sql+"\0");
    if(sqlite3_prepare_v2(db,q,-1,out st,IntPtr.Zero)!=0) { string m=U8(sqlite3_errmsg(db)); sqlite3_close(db); throw new Exception(m); }
    var rows=new List<string[]>(); int c=sqlite3_column_count(st);
    while(sqlite3_step(st)==100){ var r=new string[c]; for(int i=0;i<c;i++) r[i]=U8(sqlite3_column_text(st,i)); rows.Add(r); }
    sqlite3_finalize(st); sqlite3_close(db); return rows;
  }
}
"@
if (-not ('HsSqlite' -as [type])) { Add-Type -TypeDefinition $src }

$tz = [TimeZoneInfo]::FindSystemTimeZoneById($TimeZone)
$startLocal = [datetime]::SpecifyKind($StartDate.Date, [DateTimeKind]::Unspecified)
$sinceUtc = [TimeZoneInfo]::ConvertTimeToUtc($startLocal, $tz)
# Chromium visit_time = microseconds since 1601-01-01 UTC
$epoch = [datetime]::new(1601,1,1,0,0,0,[DateTimeKind]::Utc)
$sinceUs = [int64](($sinceUtc - $epoch).Ticks / 10)
# Drop auto subframes (3) and reloads (8) so self-refreshing tabs don't count as activity
$sql = "SELECT v.visit_time, u.url, u.title FROM visits v JOIN urls u ON u.id=v.url WHERE v.visit_time >= $sinceUs AND (v.transition & 255) NOT IN (3,8) ORDER BY v.visit_time"

$dir = Split-Path -Parent ([IO.Path]::GetFullPath($Out))
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

$all = foreach ($k in $HistoryFiles.Keys) {
  $path = $HistoryFiles[$k]
  if (-not (Test-Path -LiteralPath $path)) { Write-Warning "Not found, skipped: $k ($path)"; continue }
  $copy = Join-Path $dir "History-$k.db"
  try { Copy-Item -LiteralPath $path $copy -Force -ErrorAction Stop }   # never read the live file
  catch { Write-Warning "Could not copy $k History (close the browser and retry): $_"; continue }
  foreach ($r in [HsSqlite]::Query($copy, $sql)) {
    $local = [TimeZoneInfo]::ConvertTimeFromUtc($epoch.AddTicks([int64]$r[0] * 10), $tz)
    $hostName = try { ([uri]$r[1]).Host } catch { '' }
    # Keep host and title only; full URLs are not needed and can carry sensitive parameters
    [pscustomobject]@{ Time = $local.ToString('yyyy-MM-dd HH:mm:ss'); Browser = $k; Host = $hostName; Title = $r[2] }
  }
}
$all = @($all | Sort-Object Time)
$all | Export-Csv $Out -NoTypeInformation -Encoding UTF8
"Visits: $($all.Count) -> $Out"
