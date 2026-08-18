# Typly

Typly is a macOS AI typing assistant built with Swift.

It runs as a lightweight background app (no Dock icon) and, on a single global
shortcut, reads whatever text you have selected, decides what you probably want
done with it, and either rewrites it in place or shows the answer in a floating
glass overlay.

## Features

- Global trigger shortcut, consumed by Typly so it never reaches the front app
- Context-aware text transformation (fix spelling, rewrite, summarize, define)
- Inline replacement via the Accessibility API, with a clipboard paste fallback
- Transparent vibrant overlay for read-only results
- On-device inference through Apple Intelligence (FoundationModels)
- Native macOS app: Swift + AppKit, no dependencies

## How it works

1. You press the shortcut (default **⌥⌘Space**).
2. Typly reads the focused element's selected text through the Accessibility API.
   If the app doesn't expose it — Chromium, Electron and most web views don't —
   Typly falls back to a synthetic ⌘C and restores your clipboard afterwards.
3. The selection is classified by length and editability:

   | Selection | Editable field | Read-only text |
   |-----------|----------------|----------------|
   | One word  | Fix spelling   | Define         |
   | Multiple words | Rewrite   | Summarize      |

4. Editable results are written back over the selection; read-only results appear
   in the overlay. Errors are always shown in the overlay and never written into
   your text.

## Tech Stack

- Swift
- AppKit
- Accessibility APIs
- Carbon `RegisterEventHotKey` for the global shortcut
- FoundationModels (Apple Intelligence)
- Swift Package Manager

## Requirements

- macOS 13 or later to build and run
- macOS 26 or later with Apple Intelligence enabled for the AI features
- Accessibility permission

## Setup

Clone and build:

```bash
git clone https://github.com/maxhersc/typly.git
cd typly
./build.sh
open Typly.app
```

Then grant Accessibility permission in **System Settings › Privacy & Security ›
Accessibility** and relaunch Typly.

### Accessibility permission keeps resetting?

The permission is bound to the app's code signature. `build.sh` ad-hoc signs the
bundle, which changes the signature on every rebuild, so macOS treats each build
as a different app. Remove the stale Typly entry with the **−** button and add the
new build again. To keep the grant across rebuilds, sign with a Developer ID:

```bash
TYPLY_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./build.sh
```

## Changing the shortcut

The shortcut is stored in user defaults as a virtual key code and a Carbon
modifier mask, and is read at launch:

```bash
# ⌃⌥Space instead of ⌥⌘Space
defaults write com.typly.app HotKeyCode -int 49
defaults write com.typly.app HotKeyModifiers -int 6144
```

Modifier mask values: `cmdKey` 256, `shiftKey` 512, `optionKey` 2048,
`controlKey` 4096 — add together the ones you want. If the shortcut is already
taken by another app, Typly says so at launch instead of starting silently.

Caps Lock is deliberately not supported as a trigger: it is handled below the
event tap layer, so no app can observe it without also letting it toggle.
