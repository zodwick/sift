# Sift

Fast photo/video triage for macOS. Point it at a folder with thousands of photos, keep what you want, reject the rest.

Rejected files are moved to a `_rejected/` subfolder — nothing is ever deleted.

## Install

**Homebrew:**
```
brew install --cask sift-app
```

**Build from source (macOS 14+, Swift 5.9+):**
```bash
git clone https://github.com/yourusername/sift.git
cd sift
./build.sh
open Sift.app
```

## Usage

```bash
# Open a folder directly
open Sift.app --args ~/Pictures/vacation

# Or launch and pick a folder
open Sift.app
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `h` / `←` | Previous photo |
| `l` / `→` | Next photo |
| `j` / `↓` | Reject |
| `k` / `↑` / `Space` | Keep |
| `1-5` | Star rating |
| `z` | Undo |
| `f` | Toggle zoom |
| `g` | Toggle gallery view |
| `?` | Help overlay |

## How It Works

- Files are sorted by EXIF date (interleaves photos from multiple cameras)
- Three states: **undecided**, **kept**, **rejected**
- Undecided = rejected by default (only keep what you explicitly mark)
- Decisions are saved to `.sift_session.json` so you can resume later
- Supports JPEG, HEIC, PNG, WebP, RAW, MOV, MP4

## License

MIT
