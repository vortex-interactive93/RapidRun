### Asset Backup Cleanup

The `assets/stores/walmart` directory currently contains a large number of `*.json.bak` backup files.

These are being picked up by Flutter's asset build step and then copied into the build output, which
caused a `PathExistsException` when an identical path was written twice during incremental builds.

Recommended options (choose one):

1. Permanently delete all `*.bak` files if they are no longer needed.
2. Move them to a non-asset folder (e.g. `data_backups/` or `tools/backups/`) that is NOT listed under
   the `flutter: assets:` section of `pubspec.yaml`.
3. If you must keep them in-place, add a pre-build script that removes or renames them before `flutter build`.

Example PowerShell one-liner (run at repo root) to move them to `tools/backups_walmart`:

```powershell
New-Item -ItemType Directory -Force tools/backups_walmart | Out-Null
Get-ChildItem -Path assets/stores/walmart -Filter *.json.bak -File -Recurse | `
  Move-Item -Destination tools/backups_walmart -Force
```

Or to delete (irreversible):

```powershell
Get-ChildItem assets/stores/walmart -Filter *.json.bak -File -Recurse | Remove-Item -Force
```

Keeping this file as documentation until cleanup is finished.
