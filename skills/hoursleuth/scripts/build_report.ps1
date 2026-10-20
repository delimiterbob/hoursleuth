<#
.SYNOPSIS
  Embeds report_data.json into the report template, producing one self-contained HTML file.

.EXAMPLE
  .\build_report.ps1 -Dir C:\work\hoursleuth-run
#>
param(
  [Parameter(Mandatory)] [string]$Dir,
  [string]$Template = (Join-Path $PSScriptRoot '..\templates\report_template.html'),
  [string]$Out = (Join-Path $Dir 'activity_report.html')
)
$Dir = (Resolve-Path -LiteralPath $Dir).Path   # .NET file calls need an absolute path
if (-not [IO.Path]::IsPathRooted($Out)) { $Out = Join-Path (Get-Location).Path $Out }
$t = [IO.File]::ReadAllText((Resolve-Path $Template))
$j = [IO.File]::ReadAllText((Join-Path $Dir 'report_data.json'))
if (-not $t.Contains('/*DATA*/')) { throw "Template has no /*DATA*/ placeholder: $Template" }
[IO.File]::WriteAllText($Out, $t.Replace('/*DATA*/', $j), (New-Object Text.UTF8Encoding $false))
"Report -> $Out"
