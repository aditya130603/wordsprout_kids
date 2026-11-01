# WordSprout ages 6–12 — playable learning pilot

This is the **older learner** experience, separate from the ages 4–6 A–Z
picture/spelling lessons. It is an actual Flutter route, not a UI mockup.

## The first playable curriculum

- **3 selectable tracks:** Explorer (approx. 6–8), Adventurer (9–10), Word
  Master (11–12). Age is a starting suggestion, not a hard limit.
- **6-question placement quest** offers a recommended starting track.
- **12 story missions** (4 per track), each with an authored illustrated
  environment, context-rich short narrative, and **4 target words**:
  **48 unique words** in the first pilot.
- Every mission has: **story → 4 Word Detective questions → 4 word relationship
  questions → Sentence Mayhem → Spelling Lab → use-in-new-context question →
  completion**. Scene outcomes change after the sentence task.
- Tap-to-assemble tiles, with optional long-press dragging. Repeated tile
  letters/words retain their own selection indexes. Exercises have feedback and
  hints; they have **no forced countdown timer**.
- **Speech playback** of the original story and contextual clue through
  device TTS. No internet or account is required for solo missions.
- Mission unlocking, persisted star ratings, accuracy-based rewards, and a
  local 1–3-day review queue.
- High-contrast text, large touch targets, and flexible scrollable challenge
  layout for low-end phones.

The 12 missions are designed around situations, not isolated definitions:
lantern trail, rainy rescue, garden, lost parcel, fragile bridge, festival,
secret library, forest signals, environmental investigation, community
compromise, invention tests, and storm safety.

### Curriculum scope

This release is a **genuine pilot** with 48 vocabulary words, **not the complete
600-word target**. The planned long-term corpus is around 200 words per
learning track, built by adding and reviewing new mission packs. Gameplay
needs educational QA and hands-on usability evaluation before public launch.
Mission artwork is original procedural vector scenery; the individual word
context questions are text-based, not emoji placeholder tests.

### On-device behavior

The ages 6–12 entry appears at the upper right of the preschool home view.
Both tracks share one Flutter APK but store progress separately:
\`older_selected_track\`, \`older_stars\`, and \`older_review_due\`.
Returning to the original 4–6 home does not reset either learner's progress.

### Sentence correctness

The guided word-order puzzle accepts its target sentence and explicitly
reviewed natural alternative orders only. It is not a free-form grammar AI and
must never be described as one. The child is asked to construct the *specific
meaning* shown by the puzzle, not to produce any arbitrary valid sentence.

### Content authoring and publishing

The first mission library is in \`assets/content/older_missions_v1.json\`.
The \`OlderCourse\` validator rejects corrupt records, duplicate word tokens,
invalid relationships or inappropriate mission structure.
A downloaded HTTPS pack may optionally include \`older_missions.json\` to add
new missions or revise stories and clues, while keeping initial IDs and target
words stable. This uses the same SHA-256 verified caching mechanism as the
original WordSprout content. See \`docs/ONLINE_CONTENT_UPDATES.md\`.

To publish revisions, place \`older_missions.json\` beside the data pack's
\`words.json\`, then run \`python3 scripts/publish_content.py\` and upload the
resulting \`manifest.json\` and ZIP to the configured HTTPS content host. Code
changes to game mechanics still need a Play Store release.

## QA and APK previews

\`test/older_course_test.dart\` checks schema, vocabulary uniqueness, sentence
alternatives, route discovery, and actual Flutter mission interactions.
\`test/older_screenshot_test.dart\` captures the older home, first story, and
word detective screen at 390×844.

The separate GitHub workflow **Ages 6-12 playable preview APK** builds a
testable APK even while the original project's 14 MB preschool PNG animation
archive is awaiting its one-time GitHub upload.

**Important:** This older-track preview APK intentionally does not ship the
user-supplied 52 preschool PNG sequences while that source ZIP is absent in
GitHub. The ages 4–6 fallback continues to use bundled SVG pictures. The
separate primary Android workflow blocks full release until the binary is
included; do not call the preview a full production release.
