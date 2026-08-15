# Windows / Linux / Arch — GitHub Release attach

**Audience:** this Windows PC.  
**Full policy:** [GITHUB_RELEASES.md](GITHUB_RELEASES.md).

For version `X.Y.Z` you build **Windows**, **Linux**, and **Arch**. Upload them to tag **`vX.Y.Z`**. The Mac adds Android / macOS / iOS to **that same release**. Do not open `vX.Y.Z-windows` or any other sibling.

```powershell
cd C:\Users\rgsne\evolve
# after build_windows_installer / Linux / Arch packaging:
pwsh ./scripts/sign_download_packages.ps1 -Version 4.1.12
pwsh ./scripts/upload_release_assets.ps1 -Version 4.1.12 -Draft
```

If the Mac already created `v4.1.12`, the same command attaches your files (omit `-Draft`). When every platform you are shipping is on the draft:

```powershell
pwsh ./scripts/upload_release_assets.ps1 -Version 4.1.12 -PublishNow
```

Keep GitHub **immutable releases** off until that publish. Do not delete a published release to add a file.

**4.1.11:** historical exception — use [`v4.1.11-bundle`](https://github.com/rgsneddon/evolve/releases/tag/v4.1.11-bundle). Next ship is **`v4.1.12`**.
