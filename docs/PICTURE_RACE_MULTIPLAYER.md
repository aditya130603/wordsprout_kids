# Picture Race (4–6) — true Flutter game + private room server

**Current status:** Flutter screens and HTTP polling client are implemented and
backed by an authoritative FastAPI game room service. CI renders the *real
Flutter widgets* in lobby, round, and winner states, using clearly labeled
sample players; these tests are not recordings of live connections.

## Rules

- 2–6 friends per room, 5 rounds per match.
- The host creates a six-character room code and shares it with friends.
- A second child's account must already be an approved friend of the host
  (or have the same verified parent account). No public rooms or open chat.
- The highest *reported* alphabet reached by any joined child sets the
  room's ceiling. If one child has reached R (alphabet index 17), the
  room may choose **any of the 90 initial words from A through R**.
- This explicitly follows the current product direction. It does **not**
  mean every child in that room has personally studied every eligible word.
  If equal progress is preferred later, change this rule to the minimum
  participant letter (or select an optional common-knowledge mode).
- The server chooses one random word per round from the bounded curriculum,
  avoiding repeated words within the same five-round match.
- All players see the same word image, drawn from the current locally bundled
  curriculum. The word image is unchanged; it isn't an AI-generated example.
- Each device receives a **different deterministic shuffle** of its
  own word tiles. Letters never begin in the solved word order, unless
  unavoidable; repeated letters are separate selectable tile IDs.
- Children tap letters in any order, can undo or clear, and submit a word.
  Three incorrect attempts are allowed per round.
- **Server-arrival order** decides the winner: first correct submitted word
  closes the round immediately and awards 100 room points. Other submissions
  cannot claim the round after it closes.
- A round lasts up to **45 seconds**. If nobody succeeds, no one scores;
  after the round the correct word is revealed.
- The host moves all players to the next synchronized round.
- The leaderboard is private to that match; scores are **not yet the same as
  the separately implemented lifetime Friends League XP**.

## How to see the screens

Open WordSprout → ages 4–6 → **Games & Friends → Picture Race**.
If the online Friends League is not set up yet, the game explains that no
live room can be joined. The actual lobby/game/result Flutter widgets are
rendered and verified with:

\`\`\`bash
python3 scripts/build_assets.py
flutter pub get
flutter test --update-goldens test/picture_race_screenshot_test.dart
flutter test test/picture_race_screenshot_test.dart
\`\`\`

The resulting **23-picture-race-lobby.png**, **24-picture-race-round.png**,
and **25-picture-race-winner.png** are real 390×844 Flutter captures.
The sample room and nicknames in those files are **test data**.

## Server setup

Uses the same existing authenticated FastAPI application:
\`backend.friends_server:app\`. The game router lives in
\`backend/picture_race.py\` and follows the private Friends League
parent-approved connections.

Set the existing secure environment configuration documented in
\`docs/REWARDS_AND_FRIENDS_LEAGUE.md\`; deploy behind HTTPS, configure SMTP
for adult verification, and set the GitHub Actions variable
\`WORDSPROUT_FRIENDS_API_URL=https://<your-league-domain>\`.

Endpoints:

- \`POST /v1/race/rooms\` — create room with \`furthest_letter\` 0–25
- \`POST /v1/race/rooms/{code}/join\` — join approved friend with progress
- \`GET /v1/race/rooms/{code}\` — synchronize 1-second polling states
- \`POST /v1/race/rooms/{code}/start\` — host-only start
- \`POST /v1/race/rooms/{code}/answer\` — authoritative spelling check
- \`POST /v1/race/rooms/{code}/next\` — host-only next round

Test server rules with
\`python -m pytest -q backend/test_friends_server.py backend/test_picture_race.py\`.

## Launch limitations and safety

This is a functional room-server implementation, but online matches cannot
actually run until the hosted API is available and accounts are paired.
This is **not** a WebSocket service; the client polls each second. Real-world
latency, server clock, network fairness, reconnection, race interruptions
and device performance must be tested with at least two physical devices.
In particular, polling and differing network latency may give some players a
head start; tune a synchronized countdown and latency behavior before public
competitive launch.

The \`furthest_letter\` value comes from local app progress and is not yet
validated against signed, server-side educational achievements. The
parent-approved child identity and friendship restrictions are server-enforced.
This progress assertion should be replaced with verified learning completion
before enabling large-scale competition. Do not expose public friend search,
open messaging, or share personal information between children. Family
Settings can disable online scoring from a device; the backend also requires
separate parental approval to connect a child profile.

Never claim these screenshots show an actual live Internet multiplayer match.
