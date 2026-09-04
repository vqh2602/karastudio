<div align="center">

# 🎤 KaraStudio

**Modern, Professional Desktop Karaoke Subtitle Timing, Styling & Video Rendering Studio**

[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.41-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.11-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows-lightgrey?style=for-the-badge&logo=apple&logoColor=black)](https://github.com/vqh2602/karastudio)
[![Tests](https://img.shields.io/badge/Tests-55%20Passed-success?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/vqh2602/karastudio)
[![PRs Welcome](https://img.shields.io/badge/PRs-Welcome-brightgreen.svg?style=for-the-badge)](https://github.com/vqh2602/karastudio/pulls)

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#supported-formats">Supported Formats</a> •
  <a href="#system-requirements">Requirements</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#keyboard-shortcuts">Shortcuts</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

</div>

---

## <a id="overview"></a>📖 Overview

**KaraStudio** is an open-source, cross-platform desktop application crafted for karaoke video creators, subtitle editors, musicians, and translators. Built on **Flutter Desktop**, backed by **FFmpeg**, and powered by **`media_kit` (mpv)**, KaraStudio modernizes the traditional karaoke authoring workflow.

Say goodbye to legacy 90s-era subtitle utilities. KaraStudio offers real-time tap-to-record timing, multi-resolution waveform visualization, rich typography with dual-state sweep rendering, non-destructive pitch & tempo audio effects, and direct alpha-channel video export (Apple ProRes 4444 and WebM VP9) ready for NLEs like Adobe Premiere Pro, DaVinci Resolve, and Final Cut Pro.

---

## <a id="key-features"></a>✨ Key Features

### 🎙️ Real-Time Tap-to-Record Timing
- **Dual Timing Modes**:
  - **Tap Mode**: Tap on each word or syllable sequentially; boundaries automatically adjust without manual calculations.
  - **Hold Mode**: Press down to start singing and release to mark the word's completion for natural phrasing.
- **Smart Alignment & Gap Handling**: Automatic boundary snapping, overlap prevention, and microsecond-level accuracy (`int startUs` / `int endUs`).
- **Timing Issue Detector**: Highlights un-timed words, overlapping tokens, negative durations, and excessive gaps.
- **Token Editing**: Easily split syllables at exact character offsets, merge adjacent words, and restore missing lyrics.
- **Batch Time Shifting**: Shift timing tracks by arbitrary millisecond offsets with ripple editing support.

### 🌊 Audio Engine & Waveform Visualization
- **Multi-Resolution Waveform Peaks**: High-performance cached waveform generation streaming from FFmpeg, responsive from macroscopic overview down to microsecond zooming.
- **Hardware-Accelerated Playback**: Low-latency audio and video synchronization powered by `media_kit` (libmpv).
- **Non-Destructive Audio Effects (Live & Export)**:
  - **Pitch Shifting**: Transpose keys by ±12 semitones or tune to custom reference frequencies (A4 = 440 Hz) without affecting tempo.
  - **Multi-Tap Reverb**: Algorithmic delay decay simulation for natural room acoustic monitoring.
  - **Playback Speed**: Slow down playback (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x) with pitch-compensated tempo for effortless fast-lyric timing.

### 🎨 Typography & Visual Styling
- **Dual-State Sweep Styling**: Fine-tune both **Inactive** (base lyric color) and **Active** (karaoke sweep fill) appearances.
- **Comprehensive Typographic Controls**: Font family, font size, weight, italic, underline, letter spacing, line height, and alignments.
- **Outlines & Shadows**: Multi-layered outlines with custom stroke widths, drop shadows with configurable blur radius, color, and offset.
- **Lead-in Signal Indicators**: Built-in visual cues before singing lines begin (Countdown dots, circular meters, lamps, and pulses).
- **Kinetic Animations**: Entrance/exit transitions (Fade, Slide, Zoom) and active text effects (Bounce, Glow, Ripple).
- **Duet & Multi-Singer Support**: Define multiple actors (Lead, Backing, Duet) with distinct colors and style bindings.
- **Style Presets**: Save, load, and share `.kstyle` design packages across different songs.

### 🎬 Production-Ready Export Suite
- **Subtitle Formats**:
  - **ASS (Advanced SubStation Alpha)**: Full style declarations, color palettes, and karaoke timing (`\k` tags).
  - **SRT (SubRip)**: Clean, universally compatible line-by-line subtitles.
  - **Enhanced LRC**: Synchronized lyrics with word-level microsecond timestamps (`<mm:ss.xx>`).
- **Master Video Export**:
  - Direct MP4 (H.264 / AAC) rendering with background audio, video, or high-res artwork.
- **Transparent Alpha Channel Export (NLE-Ready)**:
  - **Apple ProRes 4444 (`.mov`)**: Lossless alpha transparency for Adobe Premiere Pro, DaVinci Resolve, and Final Cut Pro.
  - **WebM VP9 (`.webm`)**: Web-optimized transparent video overlay.
  - **PNG Image Sequence**: Frame-accurate sequence for visual effects and motion graphics compositing.
- **Effects Retention**: Preserves live pitch-shift and tempo adjustments in exported audio and video.

### 🖥️ Desktop Studio Experience
- **Fluid 3-Panel Workspace**: Resizable and collapsible panels for Lyrics, Waveform Timeline, and Style Inspector.
- **Broadcast Safe Areas**: Toggle Action Safe (93%) and Title Safe (90%) overlay grids for television and social formats.
- **Quick Command Palette (`⌘K` / `Ctrl+K`)**: Rapid keyboard navigation and action execution.
- **100-Step History**: Robust command-based Undo/Redo (`⌘Z` / `⌘⇧Z`).
- **Safety & Integrity**: Atomic project saves and automatic crash recovery snapshots.

---

## <a id="supported-formats"></a>📁 Supported Formats

| Category | Format | Extension | Capabilities |
|---|---|---|---|
| **Project** | KaraStudio Project | `.karastudio` | Native JSON project structure with microsecond precision |
| **Preset** | Style Preset | `.kstyle` | Shareable typography, color schemes, and effects |
| **Lyrics Import** | Plain Text, LRC, SRT, ASS | `.txt`, `.lrc`, `.srt`, `.ass` | Parses lyrics, actor tags (`[A]`, `[B]`, `[Duet]`), and existing timing |
| **Subtitle Export** | ASS, SRT, Enhanced LRC | `.ass`, `.srt`, `.lrc` | ASS with `\k` karaoke durations, word-level `<mm:ss.xx>` LRC |
| **Video Export** | MP4, ProRes 4444, WebM, PNG Seq | `.mp4`, `.mov`, `.webm`, `.png` | Master video or transparent overlays with alpha channel |
| **Media Input** | Audio & Video | MP3, FLAC, WAV, AAC, MP4, MKV, MOV... | Any format supported by FFmpeg and libmpv |

---

## <a id="system-requirements"></a>🖥️ System Requirements

- **Operating System**:
  - macOS 11.0 (Big Sur) or newer (Apple Silicon & Intel)
  - Windows 10 / 11 (64-bit)
- **Development Tooling**:
  - [Flutter SDK](https://flutter.dev) `^3.41.0` (with Dart `^3.11.0`)
- **FFmpeg & FFprobe**:
  - KaraStudio relies on `ffmpeg` and `ffprobe` for media probing, waveform generation, and video encoding.

### Installing FFmpeg

#### macOS (via Homebrew)
```sh
brew install ffmpeg
```
*(KaraStudio automatically searches system `PATH`, `/opt/homebrew/bin`, and `/usr/local/bin`)*.

#### Windows (via winget or Chocolatey)
```sh
# Using Windows Package Manager
winget install Gyan.FFmpeg

# Or using Chocolatey
choco install ffmpeg
```

---

## <a id="quick-start"></a>🚀 Quick Start

### 1. Clone the Repository
```sh
git clone https://github.com/vqh2602/karastudio.git
cd karastudio
```

### 2. Install Flutter Dependencies
```sh
flutter pub get
```

### 3. Run Code Analysis and Tests
KaraStudio comes with a comprehensive test suite covering serialization, timing engines, audio effects, and rendering:
```sh
# Check code style & lints
flutter analyze

# Run unit and feature tests
flutter test
```

### 4. Launch the Application

#### macOS
```sh
flutter run -d macos
```

#### Windows
```sh
flutter run -d windows
```

### 5. Build for Production

```sh
# macOS Release Bundle
flutter build macos --release

# Windows Release Executable
flutter build windows --release
```

---

## <a id="keyboard-shortcuts"></a>⌨️ Keyboard Shortcuts

| Shortcut (macOS) | Shortcut (Windows) | Action |
|---|---|---|
| <kbd>⌘</kbd> + <kbd>S</kbd> | <kbd>Ctrl</kbd> + <kbd>S</kbd> | Save Project |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>S</kbd> | <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Save Project As... |
| <kbd>⌘</kbd> + <kbd>Z</kbd> | <kbd>Ctrl</kbd> + <kbd>Z</kbd> | Undo Action |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>Z</kbd> | <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Z</kbd> | Redo Action |
| <kbd>⌘</kbd> + <kbd>K</kbd> | <kbd>Ctrl</kbd> + <kbd>K</kbd> | Open Command Palette |
| <kbd>Space</kbd> | <kbd>Space</kbd> | Play / Pause Media Playback |
| <kbd>←</kbd> / <kbd>→</kbd> | <kbd>←</kbd> / <kbd>→</kbd> | Step backward / forward 1 second |
| <kbd>Tap</kbd> / <kbd>Hold</kbd> | <kbd>Tap</kbd> / <kbd>Hold</kbd> | Synchronize lyrics in Recording Overlay |

---

## <a id="architecture"></a>🏗️ Architecture & Codebase Map

The project is structured around clean domain-driven vertical slices:

```text
lib/
├── app/
│   ├── theme/                 # Dark and light studio design systems & tokens
│   └── app.dart               # Root MaterialApp & top-level layout configuration
├── core/
│   ├── effects/               # Kinetic text effects (Transitions, Bounce, Glow, Ripple)
│   ├── export/                # ASS, SRT, LRC & raw RGBA FFmpeg video export engine
│   ├── ffmpeg/                # FFmpeg & FFprobe process wrapper and pipeline manager
│   ├── indicators/            # Visual lead-in cue engines (Dots, Countdown, Lamp, Pulse)
│   ├── lyrics/                # Lyric parsers (TXT, LRC, SRT, ASS) & token split/merge
│   ├── playback/              # MediaKit-backed playback clock & source-time sync
│   ├── presets/               # Style preset (.kstyle) serialization and manager
│   ├── renderer/              # High-performance Picture-cached karaoke Canvas renderer
│   ├── serialization/         # Atomic project serializer and recovery snapshot engine
│   ├── timing/                # Microsecond timing engine, tap-to-record & issue detector
│   ├── undo_redo/             # 100-step command history undo/redo manager
│   └── waveform/              # Multi-resolution audio peak extractor and cache
├── features/
│   ├── editor/                # Editor page shell, splitters, audio effects dialog
│   ├── export/                # Video/Subtitle export dialog & progress monitor
│   ├── inspector/             # Style inspector, color picker, actor style management
│   ├── lyrics/                # Lyrics list panel & real-time line synchronization
│   ├── palette/               # Command palette (fuzzy search & quick actions)
│   ├── timeline/              # Waveform canvas timeline, token handles, scrubbing
│   └── timing/                # Fullscreen tap/hold recording overlay & timing shift
└── models/
    ├── audio_effects.dart     # Pitch, reverb, tuning, and speed filtergraph models
    └── project_model.dart     # .karastudio JSON schema, Project, Line, Token, Actor models
```

---

## <a id="contributing"></a>🤝 Contributing

Contributions make the open-source community thrive! Whether you are reporting a bug, proposing an improvement, or submitting code, your help is welcome.

1. **Fork the Repository**
2. **Create a Feature Branch** (`git checkout -b feature/amazing-feature`)
3. **Ensure Clean Code & Tests**:
   ```sh
   flutter analyze
   flutter test
   ```
4. **Commit your Changes** (`git commit -m 'feat: add amazing feature'`)
5. **Push to your Branch** (`git push origin feature/amazing-feature`)
6. **Open a Pull Request**

Please make sure to document new features and maintain test coverage.

---

## <a id="license"></a>📄 License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more details.

---

## <a id="acknowledgements"></a>🙏 Acknowledgements

- [Flutter](https://flutter.dev) – Multi-platform application framework.
- [media_kit](https://github.com/media-kit/media-kit) – High-performance video & audio playback library for Flutter powered by `mpv`.
- [FFmpeg](https://ffmpeg.org) – The Swiss Army knife for audio/video processing and encoding.
- [flutter_riverpod](https://riverpod.dev) – Robust, compile-safe reactive state management.
