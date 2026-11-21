"""Kontrolden geçen bir partiyi yayındaki sete (hosting/words/v1.json) ekler.

Kullanım:
    python3 tools/words/merge.py tools/words/batches/en-A1-01.json --lang en --level A1
    python3 tools/words/merge.py tools/words/batches/en-ACAD-01.json --lang en   # seviye kelimede
Sonra: firebase deploy --only hosting
"""
import argparse, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIVE = ROOT / "hosting/words/v1.json"
ORDER = ["id", "lang", "term", "meaning", "pos", "level", "example", "exampleTr", "ipa", "usage", "synonyms", "topics", "exams"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("batch")
    ap.add_argument("--lang", required=True)
    ap.add_argument("--level")
    a = ap.parse_args()

    level_args = ["--level", a.level] if a.level else []
    check = subprocess.run([sys.executable, "-I", str(ROOT / "tools/words/validate.py"), a.batch, "--lang", a.lang, *level_args])
    if check.returncode != 0:
        sys.exit("Parti kontrolden geçmedi; eklenmedi.")

    live = json.loads(LIVE.read_text(encoding="utf-8"))
    batch = json.loads(pathlib.Path(a.batch).read_text(encoding="utf-8"))
    for w in batch:
        entry = dict(w, id=f"{a.lang}:{w['term'].lower()}", lang=a.lang, level=w.get("level", a.level))
        live.append({k: entry[k] for k in ORDER if k in entry})
    LIVE.write_text(json.dumps(live, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    counts = {}
    for w in live:
        if w["lang"] == a.lang:
            counts[w.get("level", "?")] = counts.get(w.get("level", "?"), 0) + 1
    print(f"Eklendi: {len(batch)} · {a.lang} seviye sayıları:", dict(sorted(counts.items())))

if __name__ == "__main__":
    main()
