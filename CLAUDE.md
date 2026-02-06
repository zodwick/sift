# Sift — Project Notes

## Key Details
- **Repo**: https://github.com/zodwick/sift (public)
- **Homebrew tap**: https://github.com/zodwick/homebrew-tap
- **Formula name**: `sift-photos` (not `sift` — taken by a grep tool in homebrew-core)
- **License**: MIT

## Build
```bash
./build.sh          # builds + assembles Sift.app
open Sift.app       # run it
```

## Release Flow

### 1. Commit & push
```bash
git add <files>
git commit -m "description"
git push origin master
```

### 2. Tag
```bash
git tag -d v0.X.0                       # delete old tag if retagging
git push origin :refs/tags/v0.X.0
git tag v0.X.0
git push origin v0.X.0
```

### 3. Create GitHub release
```bash
gh release delete v0.X.0 --repo zodwick/sift --yes
gh release create v0.X.0 --repo zodwick/sift --title "v0.X.0" --notes "Release notes."
```

### 4. Get tarball SHA
```bash
sleep 15  # wait for GitHub CDN
curl -sL "https://github.com/zodwick/sift/archive/refs/tags/v0.X.0.tar.gz" -o /tmp/sift.tar.gz
file /tmp/sift.tar.gz        # should say "gzip compressed data"
shasum -a 256 /tmp/sift.tar.gz
```

### 5. Update Homebrew formula
Edit `homebrew-tap/Formula/sift-photos.rb`:
- Update `url` tag version
- Update `sha256`

```bash
cd homebrew-tap
git add Formula/sift-photos.rb
git commit -m "Update sift-photos to v0.X.0"
git push origin main
```

### 6. Test
```bash
brew untap zodwick/tap && brew tap zodwick/tap
brew install sift-photos
cp -R $(brew --prefix)/opt/sift-photos/Sift.app ~/Applications/
open ~/Applications/Sift.app
```

## Gotchas
- Spotlight doesn't index symlinks — must `cp -R` the .app to ~/Applications
- User must open the app once after copying for Spotlight to pick it up
- Homebrew `post_install` can't write to `~/` (sandbox) — use caveats instead
- `depends_on xcode:` requires full Xcode.app — CLT-only users fail; use `depends_on :macos`
- GitHub archive tarball 404s briefly after retag — wait ~15s
- macOS icon cache is aggressive — `lsregister -f Sift.app && killall Dock`
- Icon needs both `CFBundleIconFile` and `CFBundleIconName` in Info.plist

## App Icon
- Generated via Swift/CoreGraphics script (`gen_icon_v5.swift`)
- Design: white marble bg, 3D black marble ring, frosted glass disc with sieve holes, gold keeper dot
- Source PNG → iconset via `sips` → `.icns` via `iconutil`
- Lives at `Sources/Sift/AppIcon.icns`

### Regenerating the icon
```bash
swiftc gen_icon_v5.swift -o gen_icon -framework AppKit
./gen_icon icon_1024.png

mkdir -p icon.iconset
for s in 512 256 128 32 16; do
  sips -z $((s*2)) $((s*2)) icon_1024.png --out icon.iconset/icon_${s}x${s}@2x.png
  sips -z $s $s icon_1024.png --out icon.iconset/icon_${s}x${s}.png
done

iconutil -c icns icon.iconset -o Sources/Sift/AppIcon.icns
rm -rf icon.iconset icon_1024.png
```
