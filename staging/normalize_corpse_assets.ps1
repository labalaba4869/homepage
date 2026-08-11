Add-Type -AssemblyName System.Drawing

$sourceDirectory = "D:\GameDevelop\Godot\card-search-and-attack\assets\art\character\animals"
$outputDirectory = "D:\Homepage Dev\staging\normalized_corpse_assets"
$canvasSize = 64
$padding = 2

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

Get-ChildItem -Path $sourceDirectory -Filter "corpse_*.png" -File | ForEach-Object {
    $source = New-Object System.Drawing.Bitmap($_.FullName)
    $minX = $source.Width
    $minY = $source.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $source.Height; $y++) {
        for ($x = 0; $x -lt $source.Width; $x++) {
            $pixel = $source.GetPixel($x, $y)
            if ($pixel.A -gt 16 -and ($pixel.R -gt 12 -or $pixel.G -gt 12 -or $pixel.B -gt 12)) {
                if ($x -lt $minX) { $minX = $x }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }

    if ($maxX -lt $minX -or $maxY -lt $minY) {
        throw "No visible pixels found in $($_.Name)."
    }

    $sourceWidth = $maxX - $minX + 1
    $sourceHeight = $maxY - $minY + 1
    $maxContentSize = $canvasSize - ($padding * 2)
    $scale = [Math]::Min($maxContentSize / $sourceWidth, $maxContentSize / $sourceHeight)
    $targetWidth = [Math]::Max(1, [Math]::Round($sourceWidth * $scale))
    $targetHeight = [Math]::Max(1, [Math]::Round($sourceHeight * $scale))
    $targetX = [Math]::Floor(($canvasSize - $targetWidth) / 2)
    $targetY = $canvasSize - $padding - $targetHeight

    $target = New-Object System.Drawing.Bitmap($canvasSize, $canvasSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.DrawImage(
        $source,
        (New-Object System.Drawing.Rectangle($targetX, $targetY, $targetWidth, $targetHeight)),
        $minX,
        $minY,
        $sourceWidth,
        $sourceHeight,
        [System.Drawing.GraphicsUnit]::Pixel
    )

    $outputPath = Join-Path $outputDirectory $_.Name
    $target.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $target.Dispose()
    $source.Dispose()

    [PSCustomObject]@{
        Name = $_.Name
        SourceBounds = "$minX,$minY-$maxX,$maxY"
        Output = "${canvasSize}x${canvasSize}"
        Content = "${targetWidth}x${targetHeight}"
    }
} | Format-Table -AutoSize
