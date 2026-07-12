# Subler — TrueHD Atmos → EAC3-JOC & Dolby Vision 8.1

A fork of [Subler](https://subler.org) (the macOS MP4 muxing app) that adds two things when muxing:

1. **Re-encode TrueHD Atmos → E-AC3 JOC** (Dolby Digital Plus + Atmos), 768 kbps / 5.1.
2. **Tag Dolby Vision Profile 8.1 as `dvh1`** instead of `hvc1`, so QuickTime and the Apple ecosystem recognize the Dolby Vision.

---

## ✨ Features

### TrueHD Atmos → EAC3-JOC
When you import an MKV, a new **"EAC3-JOC (Dolby Atmos)"** option appears on TrueHD tracks, alongside the existing AAC mixdowns.

On save, the pipeline runs:

```
ffmpeg (extract) → truehdd (decode Atmos master) → dee via deezy (encode) → .ec3 muxed into the MP4
```

Settings: **768 kbps, 5.1** (streaming mode). Subler already writes the proper `dec3` atom with the JOC flag.

### Dolby Vision 8.1 → dvh1
Subler tagged DV 8.1 as `hvc1` (with the DV config in a `dvcC` atom), but **QuickTime only recognizes Dolby Vision 8.1 when the sample entry is `dvh1`**. Profile 8 is now muxed as `dvh1`. **Profiles 5 and 7 are unchanged.**

---

## 🔧 Requirements (external tools)

The app drives 4 external executables, configured in **Preferences ▸ Atmos**:

| Tool | Role | License |
|------|------|---------|
| `ffmpeg` | stream extraction | open source |
| `truehdd` | TrueHD → Atmos master decode | open source (Apache-2.0), **experimental** |
| `deezy` | orchestrates ffmpeg + truehdd + dee | open source |
| `dee` | Dolby Encoding Engine | **proprietary (Dolby) — not included** |

> ⚠️ **`dee` is not included** — you provide your own copy. On Apple Silicon it is x86_64, so **Rosetta 2** is required (`softwareupdate --install-rosetta`).

`ffmpeg` and `dee` are auto-detected (PATH, `/opt/local/bin`); set `deezy` and `truehdd` manually (*Browse…*).

---

## 🚀 Usage

1. **Preferences ▸ Atmos** → set the tool paths, click *Detect installed tools*.
2. Import an MKV → on the TrueHD track choose **EAC3-JOC (Dolby Atmos)**.
3. **Save** → deezy runs for a few minutes; you get an MP4 with an E-AC3 JOC track (and, for DV 8.1 video, the `dvh1` tag).

---

## 🏗️ Build

macOS app (Apple Silicon). In Xcode: **Subler** scheme, **Release** configuration, ⌘B, then copy `Subler.app` to `/Applications`.
Ad-hoc signed (local, non-notarized). `ENABLE_HARDENED_RUNTIME = NO` so the app launches once copied out of Xcode.

---

## ⚠️ Known limitations

- **truehdd is experimental**: some TrueHD streams make it panic (a Rust crash on a parity error), and the conversion fails with "deezy failed" — that's the external tool, not the app. Most films work fine.
- Tagging DV 8.1 as `dvh1` favors Dolby Vision recognition on Apple over the HDR10 fallback on non-DV players.

---

## 📄 Credits & license

Based on **[Subler](https://github.com/SublerApp/Subler)** by Damiano Galassi — **GPL v2**; this fork stays GPL v2.
Uses **[deezy](https://github.com/jessielw/DeeZy)** and **[truehdd](https://github.com/truehdd/truehdd)**.
Requires the **Dolby Encoding Engine** (`dee`, Dolby, proprietary) — not distributed here; provide your own.
