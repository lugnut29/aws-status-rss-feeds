# Get-AwsRssFeeds.ps1
# Pulls the AWS service list directly from the S3 endpoint that powers
# health.aws.amazon.com and generates RSS feed URLs from it.
# No installs needed - pure PowerShell.
# Usage: .\Get-AwsRssFeeds.ps1

$ServicesUrl = "https://servicedata-us-west-2-prod.s3.amazonaws.com/services.json"
$RssBase     = "https://status.aws.amazon.com/rss/"
$OutTxt      = "aws_rss_feeds.txt"
$OutJson     = "aws_rss_feeds.json"

Write-Host "Fetching services.json from AWS S3..." -ForegroundColor Cyan

try {
    $raw = Invoke-WebRequest -Uri $ServicesUrl -UseBasicParsing -TimeoutSec 20
    $services = $raw.Content | ConvertFrom-Json
} catch {
    Write-Error "Failed to fetch services.json: $_"
    exit 1
}

Write-Host "Found $($services.Count) service entries." -ForegroundColor Green

# Build unique RSS URLs from the 'service' slug field
$feedUrls = $services |
    ForEach-Object { "$RssBase$($_.service).rss" } |
    Sort-Object -Unique

Write-Host "Unique RSS feeds: $($feedUrls.Count)" -ForegroundColor Green

# Save flat list
$feedUrls | Out-File -FilePath $OutTxt -Encoding UTF8
Write-Host "Saved flat list -> $OutTxt" -ForegroundColor Yellow

# Build structured JSON: ServiceName -> RegionName -> URL
$structured = @{}
foreach ($svc in $services) {
    $name   = if ($svc.service_name) { $svc.service_name } else { "Unknown" }
    $region = if ($svc.region_name)  { $svc.region_name  } else { "global"  }
    $url    = "$RssBase$($svc.service).rss"

    if (-not $structured.ContainsKey($name)) {
        $structured[$name] = @{}
    }
    $structured[$name][$region] = $url
}

# Sort and convert to JSON
$sorted = [ordered]@{}
foreach ($svcName in ($structured.Keys | Sort-Object)) {
    $sorted[$svcName] = [ordered]@{}
    foreach ($reg in ($structured[$svcName].Keys | Sort-Object)) {
        $sorted[$svcName][$reg] = $structured[$svcName][$reg]
    }
}

$sorted | ConvertTo-Json -Depth 4 | Out-File -FilePath $OutJson -Encoding UTF8
Write-Host "Saved structured JSON -> $OutJson" -ForegroundColor Yellow

# Summary
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Total feeds : $($feedUrls.Count)"
Write-Host "  Services    : $($sorted.Keys.Count)"
Write-Host "Done." -ForegroundColor Green
