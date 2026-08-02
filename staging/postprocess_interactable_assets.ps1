Add-Type -AssemblyName System.Drawing

$root = 'D:\Homepage Dev\staging'
$python = 'C:\Users\laba\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$removeKey = 'C:\Users\laba\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py'
$sceneOutput = Join-Path $root 'assets\art\scene\interactables'
$uiOutput = Join-Path $root 'assets\art\ui\battle'
New-Item -ItemType Directory -Force -Path $sceneOutput, $uiOutput | Out-Null

function Export-Quadrants {
    param(
        [string]$InputPath,
        [string]$OutputDirectory,
        [string[]]$Names,
        [int]$TargetSize
    )

    $source = [System.Drawing.Bitmap]::FromFile($InputPath)
    try {
        $halfWidth = [int]($source.Width / 2)
        $halfHeight = [int]($source.Height / 2)
        for ($index = 0; $index -lt $Names.Count; $index++) {
            $column = $index % 2
            $row = [math]::Floor($index / 2)
            $rawPath = Join-Path $OutputDirectory ($Names[$index] + '_raw.png')
            $finalPath = Join-Path $OutputDirectory ($Names[$index] + '.png')
            $cropped = New-Object System.Drawing.Bitmap($halfWidth, $halfHeight)
            $graphics = [System.Drawing.Graphics]::FromImage($cropped)
            try {
                $graphics.Clear([System.Drawing.Color]::Fuchsia)
                $graphics.DrawImage(
                    $source,
                    [System.Drawing.Rectangle]::new(0, 0, $halfWidth, $halfHeight),
                    [System.Drawing.Rectangle]::new($column * $halfWidth, $row * $halfHeight, $halfWidth, $halfHeight),
                    [System.Drawing.GraphicsUnit]::Pixel
                )
                $cropped.Save($rawPath, [System.Drawing.Imaging.ImageFormat]::Png)
            }
            finally {
                $graphics.Dispose()
                $cropped.Dispose()
            }

            $keyArgs = @(
                $removeKey,
                '--input', $rawPath,
                '--out', $finalPath,
                '--auto-key', 'none',
                '--key-color', '#ff00ff',
                '--soft-matte',
                '--transparent-threshold', '12',
                '--opaque-threshold', '220',
                '--despill',
                '--edge-contract', '1',
                '--force'
            )
            & $python @keyArgs
            if ($LASTEXITCODE -ne 0) { throw "Chroma-key removal failed for $rawPath" }
            Remove-Item -LiteralPath $rawPath -Force

            $transparent = [System.Drawing.Bitmap]::FromFile($finalPath)
            $scaledPath = Join-Path $OutputDirectory ($Names[$index] + '_scaled.png')
            try {
                $scaled = New-Object System.Drawing.Bitmap($TargetSize, $TargetSize)
                $scaledGraphics = [System.Drawing.Graphics]::FromImage($scaled)
                try {
                    $scaledGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
                    $scaledGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
                    $scaledGraphics.DrawImage($transparent, 0, 0, $TargetSize, $TargetSize)
                    $scaled.Save($scaledPath, [System.Drawing.Imaging.ImageFormat]::Png)
                }
                finally {
                    $scaledGraphics.Dispose()
                    $scaled.Dispose()
                }
            }
            finally {
                $transparent.Dispose()
            }
            Move-Item -LiteralPath $scaledPath -Destination $finalPath -Force
        }
    }
    finally {
        $source.Dispose()
    }
}

Export-Quadrants `
    -InputPath 'C:\Users\laba\.codex\generated_images\019f3c7c-aeac-7840-9ff6-2c55ff7c97eb\exec-50d3d0a5-f6b8-4a2e-9518-60d890af9c4e.png' `
    -OutputDirectory $sceneOutput `
    -Names @('abandoned_camp_closed', 'abandoned_camp_open', 'broken_storage_closed', 'broken_storage_open') `
    -TargetSize 128

$iconSheet = 'C:\Users\laba\.codex\generated_images\019f3c7c-aeac-7840-9ff6-2c55ff7c97eb\exec-53f12453-c5fd-46fe-8ea2-c1ab2a84e4b9.png'
$iconSource = [System.Drawing.Bitmap]::FromFile($iconSheet)
try {
    $halfWidth = [int]($iconSource.Width / 2)
    for ($index = 0; $index -lt 2; $index++) {
        $name = @('draw_pile', 'discard_pile')[$index]
        $rawPath = Join-Path $uiOutput ($name + '_raw.png')
        $finalPath = Join-Path $uiOutput ($name + '.png')
        $cropped = New-Object System.Drawing.Bitmap($halfWidth, $iconSource.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($cropped)
        try {
            $graphics.Clear([System.Drawing.Color]::Fuchsia)
            $graphics.DrawImage(
                $iconSource,
                [System.Drawing.Rectangle]::new(0, 0, $halfWidth, $iconSource.Height),
                [System.Drawing.Rectangle]::new($index * $halfWidth, 0, $halfWidth, $iconSource.Height),
                [System.Drawing.GraphicsUnit]::Pixel
            )
            $cropped.Save($rawPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $graphics.Dispose()
            $cropped.Dispose()
        }
        & $python $removeKey --input $rawPath --out $finalPath --auto-key none --key-color '#ff00ff' --soft-matte --transparent-threshold 12 --opaque-threshold 220 --despill --edge-contract 1 --force
        if ($LASTEXITCODE -ne 0) { throw "Chroma-key removal failed for $rawPath" }
        Remove-Item -LiteralPath $rawPath -Force
    }
}
finally {
    $iconSource.Dispose()
}
