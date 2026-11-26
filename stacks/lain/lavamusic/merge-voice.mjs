// merges lain's voice (voice.json) into the en-us locale files of lavamusic.
// fails on keys that don't exist upstream or on placeholders the original doesn't
// have, so an upstream bump can't silently break a string.
// usage: node merge-voice.mjs <voice.json> <locales/en-US dir>
import fs from "node:fs";
import path from "node:path";

const [voiceFile, dir] = process.argv.slice(2);
const voice = JSON.parse(fs.readFileSync(voiceFile, "utf8"));
const placeholders = (s) => new Set([...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]));

function merge(target, patch, where, isNew) {
	for (const [key, value] of Object.entries(patch)) {
		const at = `${where}.${key}`;
		if (typeof value === "object") {
			if (typeof target[key] !== "object") throw new Error(`unknown section ${at}`);
			merge(target[key], value, at, isNew);
			continue;
		}
		if (!(key in target)) {
			if (!isNew(at)) throw new Error(`unknown key ${at}`);
		} else {
			const have = placeholders(target[key]);
			for (const p of placeholders(value)) {
				if (!have.has(p)) throw new Error(`placeholder {${p}} not in original ${at}`);
			}
		}
		target[key] = value;
	}
}

// keys lain adds herself
const added = new Set(["player.trackStart.line"]);
for (const [file, patch] of Object.entries(voice)) {
	const p = path.join(dir, `${file}.json`);
	const data = JSON.parse(fs.readFileSync(p, "utf8"));
	merge(data, patch, file, (at) => added.has(at));
	fs.writeFileSync(p, `${JSON.stringify(data, null, "\t")}\n`);
}
console.log("voice merged");
