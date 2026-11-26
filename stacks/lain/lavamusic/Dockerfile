# syntax=docker/dockerfile:1
# lain: lavamusic from a pinned upstream commit + a small patch (text-only replies,
# aliases, prefix) + her voice for the en-us strings. update = bump the sha below and
# check that lain.patch still applies (the build fails if it doesn't).
# the stages mirror upstream's Dockerfile at that commit.

FROM oven/bun:alpine AS builder
RUN apk add --no-cache patch
ADD --keep-git-dir=false https://github.com/appujet/lavamusic.git#32e5f73727f1d9f038795806188d7d992e608b4f /app
WORKDIR /app
COPY lain.patch voice.json merge-voice.mjs /lain/
RUN patch -p1 --forward < /lain/lain.patch \
	&& bun /lain/merge-voice.mjs /lain/voice.json locales/en-US
RUN bun install --frozen-lockfile
RUN bun run build

FROM oven/bun:alpine AS runtime
WORKDIR /app
COPY --from=builder --chown=bun:bun /app/dist ./dist
COPY --from=builder --chown=bun:bun /app/locales ./locales
COPY --from=builder --chown=bun:bun /app/package.json ./package.json
COPY --from=builder --chown=bun:bun /app/bun.lock ./bun.lock
COPY --from=builder --chown=bun:bun /app/drizzle ./drizzle
COPY --from=builder --chown=bun:bun /app/src ./src
COPY --from=builder --chown=bun:bun /app/scripts ./scripts
RUN bun install --production --frozen-lockfile && \
	bunx clean-modules "**/*.d.ts" "**/@types/**" "**/*.map" "**/test/**" "**/tests/**" -y && \
	rm -rf ~/.bun /tmp /var/cache/apk /lib/apk/db \
	/app/node_modules/@esbuild* /app/node_modules/.bin/esbuild \
	/app/node_modules/typescript /app/node_modules/@libsql/linux-arm64-gnu
COPY --from=builder --chown=bun:bun /app/entrypoint.sh ./entrypoint.sh
RUN sed -i 's/\r$//' ./entrypoint.sh && chmod +x ./entrypoint.sh
RUN mkdir -p /app/lavamusic-pgdata && chown -R bun:bun /app/lavamusic-pgdata
ENTRYPOINT ["./entrypoint.sh"]
CMD ["bun", "run", "start"]
