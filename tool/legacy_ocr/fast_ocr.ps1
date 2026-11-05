[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][Windows.Media.Ocr.OcrEngine, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]
[void][Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]
[void][Windows.Storage.StorageFile, Windows.Foundation.UniversalApiContract, ContentType = WindowsRuntime]

$desktop = 'C:\Users\Thomas\OneDrive\Desktop'

foreach ($f in @('Capture1.PNG', 'Capture2.PNG', 'Capture3.PNG', 'Capture4.PNG')) {
    $p = Join-Path $desktop $f
    if (Test-Path $p) {
        Write-Output "`n=========================================="
        Write-Output "=== TEXT FROM $f ==="
        try {
            $file = [Windows.Storage.StorageFile]::GetFileFromPathAsync($p).GetAwaiter().GetResult()
            $stream = $file.OpenAsync([Windows.Storage.FileAccessMode]::Read).GetAwaiter().GetResult()
            $decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream).GetAwaiter().GetResult()
            $bitmap = $decoder.GetSoftwareBitmapAsync().GetAwaiter().GetResult()
            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
            $res = $engine.RecognizeAsync($bitmap).GetAwaiter().GetResult()
            Write-Output $res.Text
        } catch {
            Write-Output "Error: $_"
        }
    }
}
