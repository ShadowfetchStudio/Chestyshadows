# Chestyshadows

**Chestyshadows** is a native macOS chess application crafted in Swift, SwiftUI, and CoreGraphics. It combines a 120Hz ProMotion vector board renderer, dynamic multi-layered shadow lighting, a tactical Alpha-Beta + Quiescence chess engine, and real-time acoustic synthesis in a zero-dependency macOS bundle.

---

## Highlights

- **120Hz ProMotion Vector Graphics & Sculpted Pieces**
  - Custom CoreText/CoreGraphics contour-splitting Staunton renderer separates outer piece silhouettes from inner metallic inlays so pieces never suffer from transparent glyph holes.
  - Smooth cubic-bezier flight trajectories lift pieces above the board during moves and cast dynamic directional shadows that lengthen and soften with elevation.
- **Shadow & Board Studio**
  - **Shadow Threat Overlay (`⌘T`)**: Visualizes real-time square control across the board (**Gold** for White control, **Violet** for Black control, **Crimson** for contested squares).
  - **Adjustable Shadow Depth**: Fine-tune directional and contact shadow intensity from `0%` to `100%`.
  - **4 Curated Board Themes**: *Shadow Nocturne*, *Royal Walnut*, *Alabaster Marble*, and *Cyber Dusk*.
- **Complete FIDE Chess Rules & Tactical AI**
  - Full legal move validation including castling (with transit-attack checks), en passant captures, pawn promotion picker, check/checkmate, stalemate, threefold repetition, 50-move rule, and insufficient material detection.
  - **4 AI Difficulty Tiers** (*Shadow Initiate*, *Club Tactician*, *Shadow Master*, *Grandmaster Shadow*) powered by iterative-deepening Negamax with Alpha-Beta pruning, Quiescence tactical search, tapered middlegame/endgame piece-square tables, MVV-LVA move ordering, and a curated Opening Book—plus local **Pass & Play (2P)**.
- **Zero-Asset Acoustic Synthesis**
  - In-memory PCM waveform synthesis generates tactile wooden board thocks, capture snaps, castle double-thocks, check harmonics, and victory/defeat chords without external audio files.
- **Match Analysis, Clocks & Notation**
  - Live centipawn evaluation bar, opening recognition banner, clickable Standard Algebraic Notation (`SAN`) move log for scrubbing historical positions, configurable digital chess clocks (`Untimed`, `Bullet 1+0`, `Blitz 3+2`, `Blitz 5+0`, `Rapid 10+0`, `Classical 15+10`), and one-click **PGN** / **FEN** export and import.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘N` | Start New Game |
| `⌘Y` | Request Best-Move Hint |
| `⌘Z` | Undo Move |
| `⇧⌘Z` | Redo Move |
| `⌘F` | Flip Board Orientation |
| `⌘T` | Toggle Shadow Threat Overlay |
| `⇧⌘M` | Mute / Unmute Acoustic Effects |
| `⇧⌘C` | Copy Match PGN to Clipboard |

---

## Building from Source

### Requirements
- macOS 14.0 or later
- Xcode 16.0 or later

### Build & Run
```bash
xcodebuild -project Chestyshadows.xcodeproj \
  -scheme Chestyshadows \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

### Run Unit Tests
```bash
xcodebuild -project Chestyshadows.xcodeproj \
  -scheme Chestyshadows \
  -destination 'platform=macOS' \
  test
```

---

## Architecture

- `Chestyshadows/Engine/ChessTypes.swift` — Value types for squares, pieces, moves, castling rights, time controls, and game terminations.
- `Chestyshadows/Engine/BoardState.swift` — 8×8 board representation, FEN parser/serializer, attack maps, legal move generator, and Standard Algebraic Notation (`SAN`) formatter.
- `Chestyshadows/Engine/ChessAI.swift` — Curated opening book, tapered middlegame/endgame piece-square tables, iterative-deepening Alpha-Beta search, and Quiescence search.
- `Chestyshadows/Engine/GameViewModel.swift` — Main-actor state machine managing turn flow, 120Hz piece flight animations, drag-and-drop, clocks, history scrubbing, and PGN/FEN export.
- `Chestyshadows/UI/PieceVectorRenderer.swift` — Subpath-splitting vector Staunton piece renderer with 3D gradients, metallic inlays, and elevation-aware cast shadows.
- `Chestyshadows/UI/BoardCanvasView.swift` — High-frame-rate interactive board canvas with coordinate labels, legal destination markers, check radial glow, hint arrows, and promotion overlay.
- `Chestyshadows/UI/MainGameView.swift` — Full macOS window interface with evaluation bar, player strips, match configuration, shadow studio, and interactive move log.
- `Chestyshadows/Audio/SoundEffects.swift` — Real-time procedural PCM/WAV audio synthesizer.

Like this project? You can [buy me a coffee](https://www.buymeacoffee.com/shadowfetcu).

---

## License

Released under the [MIT License](LICENSE). Copyright © 2026 Shadowfetch Studio.
