# WordSprout online curriculum publishing (content only)

## What now works

The Flutter app can load a trusted, SHA-256-verified content ZIP over HTTPS,
cache it in app-private storage, and use it **offline**. Packs can change facts,
pronunciations, word illustrations, and PNG appearance sequences, or add bonus
words after the 130 A–Z starter entries. Existing learner progress stays intact.

**This is content delivery, not code hot updates.** New Flutter UI features,
new game rules implemented in Dart, native permissions and SDK upgrades still
require a Play Store release. Content must be child-appropriate and reviewed.

## Initial setup — once

1. Host `manifest.json` and `wordsprout_pack.zip` on the **same HTTPS host**
   at e.g. `https://your-content-host.example/wordsprout/`.
   Never use a private GitHub raw URL or embed a GitHub token in the app.
2. In GitHub `wordsprout_kids` → **Settings → Secrets and variables → Actions →
   Variables**, set `WORDSPROUT_CONTENT_URL` to
   `https://your-content-host.example/wordsprout/manifest.json`.
3. Rerun the **Android APK** workflow and publish this configured build once.
   An APK built without this URL stays offline-only.
4. On app launch, when a newer content version is available, the app shows the
   download size and asks for approval. The old content remains available if
   there is no internet or an update fails.

## Publish future content — no Play Store upload

Extract the prior `wordsprout_pack.zip` to a working folder. Edit
`words.json` (including exactly three simple facts per word), add corrected PNG
artwork under `media/`, and adjust the `image` and `animation_frames`
paths accordingly. Increment `content_version`; never rename or reorder
the first 130 core word IDs. Words added at the end are shown as Bonus Words.

```bash
python3 scripts/publish_content.py ./working_pack ./release
# Upload release/manifest.json + release/wordsprout_pack.zip
# to the same HTTPS folder. Publish the ZIP first, manifest last.
```

On a VPS, serve the two static files from your existing nginx HTTPS site.
Do **not** allow direct client writes; use an administrator-only deployment
process, TLS, write-protected storage and carefully reviewed new content.
Set the manifest Cache-Control to `no-cache`.

## Illustrations and animation rules

The supplied `Appear (PNG sequence).zip` contained **52 subjects**. Each has
`frame_00000.png` through `frame_00007.png`. The last frame **00007** is
also copied byte-for-byte to `still.png`. Word Discovery plays these eight
frames once; spelling, picture recognition, lists and reviews use `still.png`.

Use these frames as the visual reference for new illustration work:
- 512 × 512, PNG with transparent background
- immediately recognizable object, clear silhouette and no unrelated objects
- consistent child-friendly cartoon shading and color saturation
- one object per PNG, not a multi-word poster
- exact word/subject matching required (never show a bear as a cat)
- no text baked into object PNGs; the Flutter app renders the label itself

The downloadable pack prepared in this conversation contains **137** words
(130 core + 7 bonuses: BEAR, DONUT, ICE CREAM, NOTEBOOK, PANDA, JELLY, YACHT)
and all 52 supplied animations. No production HTTPS endpoint was configured
automatically. Content metadata includes `editorial_status=review_needed`
until an adult editor verifies every fact and asset.

## Safety

Only a trusted HTTPS origin may provide packs. The client validates file
paths, version, size, SHA-256, image presence, and fixed starter word IDs.
It does not evaluate JavaScript or download Flutter/Dart executables. The app
discloses the pack size before fetching. Android needs INTERNET permission.

Do not ask children to create accounts or enter private details to download
educational content. Online multiplayer and accounts remain a separate
parent-controlled feature.
