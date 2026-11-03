param(
  [switch]$IncludeReleaseKeystore,
  [string]$ReleaseKeystorePath = "rapidrun_upload.jks",
  [string]$ReleaseAlias = "rapidrun_upload"
)

Write-Host "=== RapidRun Android Fingerprints (Debug) ===" -ForegroundColor Cyan
pushd "$PSScriptRoot/..\android" | Out-Null
./gradlew signingReport | Select-String -Pattern "Variant: debug","SHA1","SHA-256" | ForEach-Object { $_.Line }
popd | Out-Null

if ($IncludeReleaseKeystore) {
  if (-Not (Test-Path $ReleaseKeystorePath)) {
    Write-Error "Release keystore not found at $ReleaseKeystorePath"
    exit 1
  }
  Write-Host "`n=== Release / Upload Keystore Fingerprints ===" -ForegroundColor Yellow
  & keytool -list -v -keystore $ReleaseKeystorePath -alias $ReleaseAlias
}

Write-Host "`nNext steps:" -ForegroundColor Green
Write-Host "1. Add (or verify) SHA1 + SHA-256 in Firebase Project Settings > Android app."
Write-Host "2. Re-download google-services.json and replace android/app/google-services.json"
Write-Host "3. Run: flutter clean; flutter pub get; flutter run"
