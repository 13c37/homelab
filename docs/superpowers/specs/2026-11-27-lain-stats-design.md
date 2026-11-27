# lain stats: design

## intent

a server leaderboard plus personal stats ("wrapped"-style), so people in the server can see who plays what and how much lain gets used. answers only when someone asks: no auto posts, no recaps.

## goals

- server view: songs played, hours played, hours in vc, times joined, top songs / artists / requesters
- personal view: what someone requested, how long it played, their top songs and artists, how often they skip
- time ranges: week, month, year, all time (default)
- a few fun wrapped-style facts that are cheap from the same data: most skipped song, longest vc session, busiest hour, first song ever

## non-goals

- no auto posts, scheduled recaps or dms
- no web dashboard, no cross-server totals
- no backfill: history starts on the day this ships

## anti-goals

- slowing down playback or the bot's replies (logging must never block or crash the player)
- wrong numbers after a restart or crash (open rows have to be closed sensibly)

## approaches

1. **play log (picked).** one row per played track, one row per vc session. every stat is a query over those rows.
   - pro: any time range for free, new stats work back to day one
   - con: queries are a bit more work than reading a counter
2. **counters.** increment totals per guild and per user.
   - pro: trivial reads
   - con: no time ranges, new stats start at zero, can't fix a bug after the fact
3. **both.** log plus cached counters. not worth it at this size (≈100 songs/day is a few mb/year).

## data

two new tables in `src/database/schemas.ts`, with a drizzle migration in `drizzle/postgres` (applied at startup by the existing `migrate()`):

- `plays`: id, guild_id, requester_id, title, author, uri, source, length_ms, started_at, played_ms, skipped (bool), end_reason
- `voice_sessions`: id, guild_id, channel_id, joined_at, left_at

writes:
- track start → insert a `plays` row
- track end / skip / error / stuck / player destroy → set played_ms, skipped and end_reason on the open row
- player connects → insert `voice_sessions`; player destroyed → set left_at
- startup: close rows left open by a crash (played_ms capped at length_ms, left_at = last known activity)

all writes are fire-and-forget with errors logged, never thrown into the player.

## commands

text only, lowercase (goes through the existing textify):

- `lain stats [week|month|year]`: server overview plus top 5 songs and top 5 requesters
- `lain stats me` / `lain stats @user [range]`: personal view
- `lain top songs|artists|people [range]`: top 10 list
- aliases are the builder's call. `stats` is free once pr 17 is merged (it removes `stats` from botinfo)

"played" counts a track once it has played 30 s or to its end, so instant skips don't pad the numbers. skip rate counts tracks skipped before their end.

## my calls (correct me)

- everyone in the server can see everyone's stats, no opt-out in v1 (small friends server)
- the 30 s threshold above
- no "lain wrapped" year recap command in v1, just the ranges

## left to the builder

exact query shapes, output wording, alias names, index choices.
