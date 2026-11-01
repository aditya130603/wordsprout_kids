# WordSprout Kids 🌱

An offline-first Flutter English-learning app for **ages 4–6**. The first complete starter curriculum covers **A–Z: 26 letters × 5 words = 130 individually illustrated words**.

## Curriculum and gameplay

- **130 words, 390 short facts** in versioned `assets/content/words_v1.json` (three facts per word)
- A distinct offline SVG illustration, narration via device text-to-speech, and sound replay per fact
- Picture recognition with 4 separate choices, shuffled spelling tiles with index-safe duplicate letters, and a meaning/fact question
- Every letter introduces 3 words, then unlocks 2 more after those three have been learned
- Each letter is assessed with a 5-word mixed test (spelling, recognition, and facts)
- Cumulative checkpoint after A–E, F–J, K–O, P–T, U–Y, and finally U–Z (Z completion)
- Local progress persistence and scheduled revision (1, 3, 7, 14, 30, 60 days)
- Alphabet trail, all-letter library, progress and review queue, and warm garden UI

Letter **X** includes X-RAY and XYLOPHONE and also familiar words **FOX**, **BOX**, and **TAXI** that contain the letter X. It does not misrepresent these as X-initial words.

## Run and build

Use a current stable Flutter SDK and Python 3:

```bash
python3 scripts/build_assets.py
flutter create --platforms=android --project-name wordsprout_kids .
flutter pub get
flutter test --update-goldens test/screenshot_test.dart
flutter test
flutter run
flutter build apk --release
```

The first asset-build run needs an internet connection to fetch illustration sources. The build bundles all 130 illustrations into the APK; **children do not need an internet connection to learn or replay content**.

### Download the Android APK

GitHub Actions → **Android APK** → latest successful run → **wordsprout-kids-release-apk** artifact. The APK is built via `flutter build apk --release`. This is a development APK and has not been subjected to independent child usability sessions or real-device QA.

## Artwork and educational QA

The first five A assets are custom. Illustrations for additional unusual vocabulary are generated from hand-authored vectors in `scripts/build_assets.py`; remaining illustrated subjects use **Twemoji (CC BY 4.0)**. See [ASSET_CREDITS.md](ASSET_CREDITS.md). The build script validates that exactly 130 distinct local SVG files are present and writes a SHA-256 artwork manifest. Never depend on emoji fonts to render the answers in a running lesson.

**Editorial status:** Starter facts are candidate educational content, not independently certified; a human reviewer should assess every illustration, fact, pronunciation and developmental suitability before public release.

## Privacy and future phases

Offline solo lessons work without an account. The Games & Friends area is intentionally locked until reciprocal guardian approval, secure rooms, authenticated server-authoritative scoring, and a child privacy/legal review are implemented. No unrestricted public chat or stranger matchmaking is included.

This release implements the **A–Z starter learning curriculum**, not a complete English dictionary and not the separately deferred online multiplayer or WordMayhem features.
