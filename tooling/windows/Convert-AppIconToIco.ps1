$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$sourcePath = Join-Path $projectRoot 'windows\runner\resources\app_icon_source.png'
$outputPath = Join-Path $projectRoot 'windows\runner\resources\app_icon.ico'

if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Icon source was not found: $sourcePath"
}

Add-Type -AssemblyName System.Drawing
$source = [System.Drawing.Bitmap]::FromFile($sourcePath)
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$images = New-Object 'System.Collections.Generic.List[byte[]]'

try {
    foreach ($size in $sizes) {
        $bitmap = New-Object System.Drawing.Bitmap(
            $size,
            $size,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.DrawImage($source, 0, 0, $size, $size)
        $graphics.Dispose()

        $xorPixels = New-Object byte[] ($size * $size * 4)
        $maskStride = [int]([math]::Ceiling($size / 32.0) * 4)
        $andMask = New-Object byte[] ($maskStride * $size)
        for ($row = 0; $row -lt $size; $row++) {
            $sourceY = $size - 1 - $row
            for ($x = 0; $x -lt $size; $x++) {
                $color = $bitmap.GetPixel($x, $sourceY)
                $offset = ($row * $size + $x) * 4
                $xorPixels[$offset] = $color.B
                $xorPixels[$offset + 1] = $color.G
                $xorPixels[$offset + 2] = $color.R
                $xorPixels[$offset + 3] = $color.A
                if ($color.A -lt 128) {
                    $maskOffset = $row * $maskStride + [int][math]::Floor($x / 8.0)
                    $andMask[$maskOffset] = $andMask[$maskOffset] -bor (1 -shl (7 - ($x % 8)))
                }
            }
        }

        $entryStream = New-Object System.IO.MemoryStream
        $entryWriter = New-Object System.IO.BinaryWriter($entryStream)
        $entryWriter.Write([uint32]40)
        $entryWriter.Write([int32]$size)
        $entryWriter.Write([int32]($size * 2))
        $entryWriter.Write([uint16]1)
        $entryWriter.Write([uint16]32)
        $entryWriter.Write([uint32]0)
        $entryWriter.Write([uint32]($xorPixels.Length + $andMask.Length))
        $entryWriter.Write([int32]0)
        $entryWriter.Write([int32]0)
        $entryWriter.Write([uint32]0)
        $entryWriter.Write([uint32]0)
        $entryWriter.Write($xorPixels)
        $entryWriter.Write($andMask)
        $entryWriter.Flush()
        $images.Add($entryStream.ToArray())
        $entryWriter.Dispose()
        $entryStream.Dispose()
        $bitmap.Dispose()
    }

    $stream = [System.IO.File]::Create($outputPath)
    $writer = New-Object System.IO.BinaryWriter($stream)
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$sizes.Count)

    $offset = 6 + 16 * $sizes.Count
    for ($index = 0; $index -lt $sizes.Count; $index++) {
        $size = $sizes[$index]
        $image = $images[$index]
        $dimension = if ($size -eq 256) { 0 } else { $size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$image.Length)
        $writer.Write([uint32]$offset)
        $offset += $image.Length
    }

    foreach ($image in $images) {
        $writer.Write($image)
    }
    $writer.Flush()
    $writer.Dispose()
    $stream.Dispose()
}
finally {
    $source.Dispose()
}

Write-Output "Windows icon created: $outputPath"
