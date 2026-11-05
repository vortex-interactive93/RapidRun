[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]
[void][Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]
[void][Windows.Storage.StorageFile, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]

function Get-OcrText($imgPath) {
    $fileTask = [Windows.Storage.StorageFile]::GetFileFromPathAsync($imgPath)
    while (-not $fileTask.IsCompleted) { Start-Sleep -Milliseconds 50 }
    $file = $fileTask.GetResults()

    $streamTask = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read)
    while (-not $streamTask.IsCompleted) { Start-Sleep -Milliseconds 50 }
    $stream = $streamTask.GetResults()

    $decoderTask = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)
    while (-not $decoderTask.IsCompleted) { Start-Sleep -Milliseconds 50 }
    $decoder = $decoderTask.GetResults()

    $bmpTask = $decoder.GetSoftwareBitmapAsync()
    while (-not $bmpTask.IsCompleted) { Start-Sleep -Milliseconds 50 }
    $bitmap = $bmpTask.GetResults()

    $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    $ocrTask = $engine.RecognizeAsync($bitmap)
    while (-not $ocrTask.IsCompleted) { Start-Sleep -Milliseconds 50 }
    $result = $ocrTask.GetResults()

    return $result.Text
}

$artDir = 'C:\Users\Thomas\AppData\Local\Google\AndroidStudio2026.1.4\projects\rapidrun.614aaaa\.artifacts\0baf10ab-8691-4ae0-a767-96242cc9a699'

foreach ($imgName in @('Capture1.PNG', 'Capture2.PNG', 'Capture3.PNG', 'Capture4.PNG')) {
    $p = Join-Path $artDir $imgName
    if (Test-Path $p) {
        Write-Output "`n=========================================="
        Write-Output "=== TEXT FROM $imgName ==="
        try {
            $txt = Get-OcrText $p
            Write-Output $txt
        } catch {
            Write-Output "OCR Error: $_"
        }
    }
}
