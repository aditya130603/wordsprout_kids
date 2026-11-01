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

## First-install PNG artwork: one-time binary upload

The app now imports `assets/content/starter_pack.zip` during first launch.
That file contains all **52 eight-frame animations**, their `00007` final
stills, and the **137-word** starter/bonus catalog. It needs **no internet**
to display this content once included in the APK.

**Required before the new APK can be released:** upload the supplied
`starter_pack.zip` to GitHub at exactly
`assets/content/starter_pack.zip`. This connected GitHub workflow currently
cannot upload ZIP binary bytes directly, so the app code has been committed
but the first-install binary asset still needs this one-time addition.
CI intentionally blocks release APK builds when the ZIP is absent.
`scripts/verify_starter_pack.py` checks the exact source before packaging.

After that one-time release, the separate online system below can publish
new fact/picture/word packs without a Play Store update, once the HTTPS
manifest URL is configured in GitHub Actions.

## Online content packs (no store update for words)

WordSprout now supports **HTTPS word/artwork packs**: corrections, extra
vocabulary, pronunciation text, and appearance PNG sequences can be published
independently of app releases. A downloaded update is checked by SHA-256,
saved for offline use, and loaded without changing the 130 fixed starter IDs.

The supplied PNG-sequence archive has been converted into a ready-to-host pack:
**52 eight-frame animations**, with frame `00007` used as the still, plus
**7 bonus words**. The hosting URL must first be configured on the initial
app release. See [online publishing instructions](docs/ONLINE_CONTENT_UPDATES.md).

Important: the app does **not** auto-connect to the user's private GitHub
repository. A publicly accessible HTTPS content host is required. New Flutter
code or game mechanics still need a Play Store update.

## Run and build

Use a current stable Flutter SDK and Python 3:

```bash
python3 scripts/build_assets.py
flutter create --platforms=android --project-name wordsprout_kids .
flutter pub get
flutter test --update-goldens test/screenshot_test.dart
flutter test
flutter run
flutter build apk --release --dart-define=WORDSPROUT_CONTENT_URL=https://YOUR_HOST/wordsprout/manifest.json
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
