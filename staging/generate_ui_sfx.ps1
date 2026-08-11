$sampleRate = 44100
$outputDirectory = "D:\Homepage Dev\staging\ui_sfx"

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

function Add-Tone {
    param(
        [double[]]$Buffer,
        [double]$Start,
        [double]$Duration,
        [double]$Frequency,
        [double]$Amplitude,
        [double]$Decay = 8.0,
        [double]$Harmonic = 0.0
    )
    $startSample = [Math]::Floor($Start * $sampleRate)
    $endSample = [Math]::Min($Buffer.Length, [Math]::Ceiling(($Start + $Duration) * $sampleRate))
    for ($index = $startSample; $index -lt $endSample; $index++) {
        $time = ($index - $startSample) / [double]$sampleRate
        $progress = $time / $Duration
        $envelope = [Math]::Sin([Math]::Min(1.0, $time / 0.008) * [Math]::PI / 2.0) * [Math]::Exp(-$Decay * $progress)
        $wave = [Math]::Sin(2.0 * [Math]::PI * $Frequency * $time)
        if ($Harmonic -gt 0.0) {
            $wave += [Math]::Sin(2.0 * [Math]::PI * $Frequency * 2.0 * $time) * $Harmonic
        }
        $Buffer[$index] += $wave * $Amplitude * $envelope
    }
}

function Add-SoftNoise {
    param(
        [double[]]$Buffer,
        [double]$Start,
        [double]$Duration,
        [double]$Amplitude,
        [double]$Decay = 10.0
    )
    $random = [System.Random]::new(61)
    $startSample = [Math]::Floor($Start * $sampleRate)
    $endSample = [Math]::Min($Buffer.Length, [Math]::Ceiling(($Start + $Duration) * $sampleRate))
    for ($index = $startSample; $index -lt $endSample; $index++) {
        $time = ($index - $startSample) / [double]$sampleRate
        $progress = $time / $Duration
        $Buffer[$index] += (($random.NextDouble() * 2.0) - 1.0) * $Amplitude * [Math]::Exp(-$Decay * $progress)
    }
}

function Save-Wave {
    param(
        [string]$Name,
        [double]$Duration,
        [scriptblock]$Compose
    )
    $sampleCount = [Math]::Ceiling($Duration * $sampleRate)
    $buffer = New-Object double[] $sampleCount
    & $Compose $buffer
    $path = Join-Path $outputDirectory $Name
    $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($stream)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $sampleCount * 2))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
    $writer.Write([int]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * 2))
    $writer.Write([int16]2)
    $writer.Write([int16]16)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $writer.Write([int]($sampleCount * 2))
    foreach ($sample in $buffer) {
        $clamped = [Math]::Max(-0.95, [Math]::Min(0.95, $sample))
        $writer.Write([int16]([Math]::Round($clamped * 32767.0)))
    }
    $writer.Dispose()
    $stream.Dispose()
    Get-Item $path | Select-Object Name, Length
}

Save-Wave "search_empty.wav" 0.20 {
    param($buffer)
    Add-Tone $buffer 0.00 0.18 150 0.22 7.0 0.0
    Add-Tone $buffer 0.00 0.12 92 0.14 10.0 0.0
    Add-SoftNoise $buffer 0.00 0.07 0.07 15.0
}

Save-Wave "search_loot.wav" 0.22 {
    param($buffer)
    Add-Tone $buffer 0.00 0.15 880 0.16 10.0 0.20
    Add-Tone $buffer 0.06 0.14 1320 0.18 9.0 0.16
}

Save-Wave "search_rare.wav" 0.48 {
    param($buffer)
    Add-Tone $buffer 0.00 0.24 784 0.19 7.0 0.25
    Add-Tone $buffer 0.07 0.26 1175 0.21 6.5 0.24
    Add-Tone $buffer 0.14 0.30 1568 0.23 6.0 0.20
    Add-Tone $buffer 0.18 0.22 2352 0.08 8.0 0.05
}

Save-Wave "merchant_sell.wav" 0.25 {
    param($buffer)
    Add-Tone $buffer 0.00 0.13 1047 0.15 10.0 0.18
    Add-Tone $buffer 0.07 0.16 1568 0.18 9.0 0.16
    Add-SoftNoise $buffer 0.00 0.05 0.025 17.0
}

Save-Wave "merchant_buy.wav" 0.32 {
    param($buffer)
    Add-Tone $buffer 0.00 0.18 523 0.14 8.0 0.18
    Add-Tone $buffer 0.06 0.18 659 0.16 7.5 0.16
    Add-Tone $buffer 0.12 0.20 784 0.18 7.0 0.14
}
