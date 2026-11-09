Add-Type -AssemblyName System.Drawing
$srcPath = 'C:\Users\legen\.gemini\antigravity\brain\5086cb98-e8b2-4298-b89c-0d739bb026ab\.user_uploaded\media_1794258944259_3232c571.jpg'
$img = [System.Drawing.Bitmap]::FromFile($srcPath)
$w = $img.Width
$h = $img.Height

$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($img, 0, 0, $w, $h)
$g.Dispose()
$img.Dispose()

$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$bmpData = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $bmpData.Stride
$bytes = New-Object byte[] ($stride * $h)
[System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $bytes, 0, $bytes.Length)

$queue = New-Object System.Collections.Generic.Queue[int]
$visited = New-Object bool[] ($w * $h)

for ($x = 0; $x -lt $w; $x++) {
    $queue.Enqueue($x); $visited[$x] = $true
    $idxBottom = ($h - 1) * $w + $x
    $queue.Enqueue($idxBottom); $visited[$idxBottom] = $true
}
for ($y = 0; $y -lt $h; $y++) {
    $idxLeft = $y * $w
    $queue.Enqueue($idxLeft); $visited[$idxLeft] = $true
    $idxRight = $y * $w + ($w - 1)
    $queue.Enqueue($idxRight); $visited[$idxRight] = $true
}

while ($queue.Count -gt 0) {
    $cur = $queue.Dequeue()
    $cx = $cur % $w
    $cy = [math]::Floor($cur / $w)
    $offset = $cy * $stride + $cx * 4
    
    $b = $bytes[$offset]
    $gVal = $bytes[$offset + 1]
    $r = $bytes[$offset + 2]
    
    if ($r -gt 220 -and $gVal -gt 220 -and $b -gt 220) {
        $bytes[$offset + 3] = 0
        
        $neighbors = @(
            @($cx + 1, $cy),
            @($cx - 1, $cy),
            @($cx, $cy + 1),
            @($cx, $cy - 1)
        )
        foreach ($n in $neighbors) {
            $nx = $n[0]; $ny = $n[1]
            if ($nx -ge 0 -and $nx -lt $w -and $ny -ge 0 -and $ny -lt $h) {
                $nidx = $ny * $w + $nx
                if (-not $visited[$nidx]) {
                    $visited[$nidx] = $true
                    $queue.Enqueue($nidx)
                }
            }
        }
    }
}

$minX = $w; $maxX = 0; $minY = $h; $maxY = 0
for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $offset = $y * $stride + $x * 4
        if ($bytes[$offset + 3] -gt 10) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bmpData.Scan0, $bytes.Length)
$bmp.UnlockBits($bmpData)

$cropW = $maxX - $minX + 1
$cropH = $maxY - $minY + 1
Write-Host "Crop bbox: $minX, $minY, Width: $cropW, Height: $cropH"
$cropRect = New-Object System.Drawing.Rectangle($minX, $minY, $cropW, $cropH)
$cropped = $bmp.Clone($cropRect, $bmp.PixelFormat)
$cropped.Save('cartoon-cursor.png', [System.Drawing.Imaging.ImageFormat]::Png)
$cropped.Dispose()
$bmp.Dispose()
Write-Host "Saved cartoon-cursor.png successfully"

