Add-Type -Path 'C:\Users\Thomas\VSCodeWorkspaces\RapidRun\OcrHelper.cs' -ReferencedAssemblies "Windows.Foundation.UniversalApiContract"

$desktop = 'C:\Users\Thomas\OneDrive\Desktop'

foreach ($f in @('Capture1.PNG', 'Capture2.PNG', 'Capture3.PNG', 'Capture4.PNG')) {
    $p = Join-Path $desktop $f
    if (Test-Path $p) {
        Write-Output "`n=========================================="
        Write-Output "=== TEXT FROM $f ==="
        try {
            $txt = [OcrHelper]::ExtractText($p)
            Write-Output $txt
        } catch {
            Write-Output "Error: $_"
        }
    }
}
