# WordSprout — achievements, XP and private friends league

This feature is for **ages 6–12**; it doesn't change the 4–6 alphabet flow.

## Player-facing rewards (offline now)

- First correct response per mission question: **+10 XP**.
- Correct after one or more wrong attempts: **+4 XP**.
- Sentence Mayhem first-try success: **+15 XP**, else **+6 XP**.
- First-ever finish of a mission: **+20 XP**.
- First-ever mistake-free completion: extra **+10 XP**.
- Correctly recalled word: **+5 XP**, once per word per calendar day,
  with **50 XP maximum per day** from reviews.
- Mission stars: 1–3 based on accuracy; stars are distinct from XP.
- Ten earned badges (First Footprint, Clue Finder, Story Scout,
  Three-Star Thinker, Memory Keeper, Bright Spark, Word Explorer,
  Shining Mind, Careful Champion, Word Legend).
- XP grants are durable local events keyed by stage/mission/question. Replaying
  a previously scored item **never increases XP**.
- Static congratulatory text is displayed beside the fixed bottom button,
  e.g. **Well done! +10 XP earned**. No intrusive confetti or extra animations.
- Badges are shown in the Rewards page as achieved or with progress bars.
- No payments, random loot boxes, pressure countdowns or public rankings.

The local reward ledger uses SharedPreferences and is intended to motivate
learning **only on that device**. It cannot be trusted as online competitive
evidence. Review scheduling stores incorrectly recalled items for retry sooner.

## Online competition: implementation vs activation

We have implemented an **optional private leaderboard backend** and a Flutter
client that can connect to it. The feature is **not live until** an operator
deploys this service and configures the two environment URLs.

Backend:
- Parent email one-time code verification via operator SMTP.
- Parent-managed child profiles with **preselected pseudonyms only**.
- Parent explicitly opts in to each child's private friends feature.
- One-time device pairing codes (15 minutes) and encrypted Android child
  session tokens (Android Keystore via flutter_secure_storage).
- Parent-to-parent invitation codes (24 hours); no open lookup/search.
- Leaderboard lists self + approved friends only; no global rankings, chat,
  profile photos, dates of birth, contact lists, geolocation or free text.
- All points submitted to the online league are computed **by the server**:
  it checks each answer against the authored curriculum and gives XP at most
  once per question. Completion adds server-checked bonuses.
- Online leaderboards start a new week on **Monday 00:00 UTC**.
- Each parent can delete a child's competitive profile and all associated
  friendships, sessions, score history and invites.

**Crucial: offline XP is not the same as online verified XP.** Children can
always continue offline, but the Friends League ranks *new* answers that the
server actually validates while the device is connected and paired. We never
silently upload unverified local points into a public/social ranking.

## Deployment (operator setup)

Use the existing VPS only after making a backup and selecting a new isolated
hostname, such as \`league.example.com\`. Nothing in the build currently
touches your production VPS. Avoid sharing the API's host with unrelated
admin endpoints.

1. On Ubuntu, install Python 3.12+, create a **non-root** service user,
   provision a private persistent data directory and set permissions.
2. From repository root:

   \`\`\`bash
   python3 -m venv .venv
   .venv/bin/pip install -r backend/requirements.txt
   \`\`\`

3. Configure required secrets through a protected environment file, not
   in Git or the APK:

   \`\`\`
   WORDSPROUT_LEAGUE_DB=/srv/wordsprout-private/league.sqlite
   WORDSPROUT_LEAGUE_SECRET=<random 64+ character unique secret>
   WORDSPROUT_SMTP_HOST=<your SMTP provider>
   WORDSPROUT_SMTP_USER=<SMTP login>
   WORDSPROUT_SMTP_PASSWORD=<SMTP secret>
   WORDSPROUT_SMTP_FROM=<verified sender email>
   WORDSPROUT_SMTP_PORT=587
   \`\`\`

4. From repo root, run behind a TLS-terminating, rate-limiting reverse
   proxy such as nginx:

   \`\`\`bash
   .venv/bin/uvicorn backend.friends_server:app --host 127.0.0.1 --port 18795
   \`\`\`

5. Set nginx to HTTPS, require modern TLS and set appropriate security
   headers. Configure per-IP and per-email rate limits at the proxy and
   protect the SMTP endpoint from abuse. Back up encrypted private data.
   A secret rotation should revoke sessions.
6. Test the parent portal at
   \`https://league.example.com/parents\`. One parent requests an emailed code,
   verifies it, chooses a preset nickname, accepts the required consent,
   issues a one-time child device pairing code. Another parent accepts an
   invitation for their child.
7. In GitHub repo → Settings → Secrets and variables → Actions →
   **Variables**, set:

   \`\`\`
   WORDSPROUT_FRIENDS_API_URL=https://league.example.com
   WORDSPROUT_CONTENT_URL=https://your-static-content-host/wordsprout/manifest.json
   \`\`\`

   Re-run the **Ages 6–12 playable preview APK** workflow and install that
   specific APK. Future in-app point events will then be sent to the league
   when online (and otherwise safely ignored).

8. API backend regression tests:

   \`\`\`bash
   .venv/bin/pip install -r backend/requirements-dev.txt
   .venv/bin/python -m pytest -q backend/test_friends_server.py
   \`\`\`

The normal Android APK build still requires the separate 52-animation binary
asset \`assets/content/starter_pack.zip\`. The ages 6–12 preview builder
works independently of the missing preschool archive.

## Security and child protection before launch

The server and portal are functional starter infrastructure, **not a
certification of legal compliance or a third-party security audit**.
Google Play Families policy requires adult controls around social features
and adult action before children can exchange personal information. Since the
user base includes children, review Indian DPDP requirements for verifiable
parental consent, together with the laws of any other launch jurisdictions.
An email owner is **not necessarily a verified adult**, so the production
parent-verification mechanism requires independent compliance assessment.

Recommended further work before inviting real families:
- Stronger adult verification and accessible parent consent notice
- Robust request-rate limiting per account and per network, monitoring,
  penetration testing and anti-bot controls
- Production-grade database deployment, migrations, encrypted backups and
  disaster recovery
- Email delivery monitoring and robust one-time-code anti-abuse
- Verified incident reporting, audit logs and privacy deletion policies
- Clear wellbeing settings (hide ranking, no public shaming or streak pressure)
- QA with real Android devices, including low-memory and older devices
- Parent-managed friend removal control (parent can currently delete the entire
  child profile; a per-friend removal endpoint is recommended before launch)

A hard-coded public leaderboard or rankings containing dummy classmates would
mislead users and is intentionally omitted.
