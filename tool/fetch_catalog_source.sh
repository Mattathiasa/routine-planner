#!/usr/bin/env bash
# Downloads the pinned genshin-db npm package and extracts the slice of its
# English dataset that tool/build_catalog.dart consumes, into
# tool/data/vendor/. Run from the repo root:
#
#   bash tool/fetch_catalog_source.sh
#
# The vendor files are committed, so this only needs re-running to bump
# GENSHIN_DB_VERSION. Only names and numbers are extracted — never images,
# icons or other game art (see CLAUDE.md).
set -euo pipefail

GENSHIN_DB_VERSION="5.2.15"
TARBALL_URL="https://registry.npmjs.org/genshin-db/-/genshin-db-${GENSHIN_DB_VERSION}.tgz"

cd "$(dirname "$0")/.."
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Downloading genshin-db@${GENSHIN_DB_VERSION} ..."
curl -sL -o "$WORK_DIR/genshin-db.tgz" "$TARBALL_URL"
TARBALL_SHA256="$(shasum -a 256 "$WORK_DIR/genshin-db.tgz" | cut -d' ' -f1)"

tar -xzf "$WORK_DIR/genshin-db.tgz" -C "$WORK_DIR" \
  package/src/min/data.min.json package/LICENSE

mkdir -p tool/data/vendor
cp "$WORK_DIR/package/LICENSE" tool/data/vendor/LICENSE-genshin-db

GENSHIN_DB_VERSION="$GENSHIN_DB_VERSION" TARBALL_SHA256="$TARBALL_SHA256" \
WORK_DIR="$WORK_DIR" python3 - <<'PY'
import json, os
from datetime import datetime, timezone

src = json.load(open(os.environ["WORK_DIR"] + "/package/src/min/data.min.json"))
en = src["data"]["English"]

# Only the structural fields the catalog builder reads. Prose (stories,
# lore descriptions, skill text) is deliberately dropped; the one
# exception is the description of EXP items, whose "Gives N EXP." line is
# the dataset's only machine-readable EXP value.
out = {
    "provenance": {
        "package": "genshin-db",
        "version": os.environ["GENSHIN_DB_VERSION"],
        "tarballSha256": os.environ["TARBALL_SHA256"],
        "license": "MIT (tool/data/vendor/LICENSE-genshin-db)",
        "extractedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    },
    "characters": {
        k: {f: v[f] for f in ("name", "rarity", "elementText", "weaponText", "costs") if f in v}
        for k, v in en["characters"].items()
    },
    "talents": {
        k: {"costs": v["costs"]} for k, v in en["talents"].items() if "costs" in v
    },
    "weapons": {
        k: {f: v[f] for f in ("name", "rarity", "weaponText", "costs") if f in v}
        for k, v in en["weapons"].items()
    },
    "materials": {
        k: {
            f: v[f]
            for f in (
                "name", "typeText", "category", "rarity", "daysOfWeek",
                "dropDomainName", "sources",
            )
            if f in v
        }
        | (
            {"description": v.get("description", "")}
            if v.get("category") in ("EXP_FRUIT", "WEAPON_EXP_STONE")
            else {}
        )
        for k, v in en["materials"].items()
    },
    "talentmaterialtypes": en["talentmaterialtypes"],
    "weaponmaterialtypes": en["weaponmaterialtypes"],
    "crafts": {
        k: {f: v[f] for f in ("name", "resultCount", "recipe") if f in v}
        for k, v in en["crafts"].items()
    },
}

path = "tool/data/vendor/genshin_db_extract.json"
with open(path, "w") as f:
    json.dump(out, f, indent=1, sort_keys=True)
print(f"Wrote {path} ({os.path.getsize(path) // 1024} KB)")
PY

echo "Done. Vendor files in tool/data/vendor/"
