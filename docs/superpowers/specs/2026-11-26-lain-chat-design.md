# lain chat: v1 framework

status: code written, not typechecked, not built, not deployed.

## what it does
- answers an @mention, a reply to her, or `lain ...` / `tanya ...` that is not a command.
- reads the last 50 messages of that channel only when addressed. stores and logs no chat content.
- local model through lm studio. off unless `LLM_URL` is set.
- no pings from model output, max 4 messages per answer, 8 s cooldown per user, one answer per channel at a time.
- every error answers `brain's offline.`

## enable (in order)
1. typecheck: `docker build --target builder` of `stacks/lain/lavamusic`, then `node_modules/.bin/tsc --noEmit -p .`
2. windows firewall: add ct 100 to the "hermes only" rule for port 1234 (needs explicit ok).
3. server `.env`: `LLM_URL=http://<pc-lan-ip>:1234/v1`, optional `LLM_MODEL`.
4. merge to `main`, rebuild, `docker compose up -d`.

## later
- "think harder" mode, private web search, images, per-server toggle, token limit for lm studio.
- model comparison and discord policy check (research was stopped early).
- watch: `lain <typo>` now goes to chat; check the shared model with hermes under load.
