"""LEXA kelime partisi kontrolü.

Kullanım:
    python3 tools/words/validate.py tools/words/batches/en-A1-01.json --lang en --level A1
    python3 tools/words/validate.py tools/words/batches/en-ACAD-01.json --lang en   # seviye kelimede

Kontroller: zorunlu alanlar dolu, tür/seviye geçerli, okunuş /…/ biçiminde,
parti içinde ve yayındaki sette (hosting/words/v1.json) tekrar yok.
Örnek cümlede kelimenin geçmemesi yalnızca uyarıdır (çekimli hâller olabilir).
"""
import argparse, json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LIVE = ROOT / "hosting/words/v1.json"
POS = {"isim", "fiil", "sıfat", "zarf", "edat", "bağlaç", "zamir", "ünlem", "ifade"}
LEVELS = {"A1", "A2", "B1", "B2", "C1", "C2"}
REQUIRED = ["term", "meaning", "pos", "ipa", "example", "exampleTr", "usage"]
EXAMS = {"IELTS", "TOEFL", "YDS", "GRE", "SAT"}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("batch")
    ap.add_argument("--lang", required=True)
    ap.add_argument("--level", choices=sorted(LEVELS), help="Partideki tüm kelimelerin seviyesi; yoksa her kelimede 'level' olmalı")
    a = ap.parse_args()

    batch = json.loads(pathlib.Path(a.batch).read_text(encoding="utf-8"))
    live = {w["id"] for w in json.loads(LIVE.read_text(encoding="utf-8"))}
    errors, warnings, seen = [], [], set()

    for i, w in enumerate(batch, 1):
        tag = f"#{i} {w.get('term', '?')}"
        for f in REQUIRED:
            if not str(w.get(f, "")).strip():
                errors.append(f"{tag}: '{f}' boş")
        level = w.get("level", a.level)
        if level not in LEVELS:
            errors.append(f"{tag}: seviye yok ya da geçersiz '{level}'")
        bad_exams = set(w.get("exams", [])) - EXAMS
        if bad_exams:
            errors.append(f"{tag}: geçersiz sınav etiketi {sorted(bad_exams)}")
        if w.get("pos") not in POS:
            errors.append(f"{tag}: geçersiz tür '{w.get('pos')}'")
        ipa = w.get("ipa", "")
        if not re.fullmatch(r"/[^/\s][^/]*/", ipa) or re.search(r"[ɹ͡.]", ipa):
            errors.append(f"{tag}: okunuş biçimi '{ipa}' (sözlük yazımı bekleniyor, ör. /ˈbrekfəst/)")
        wid = f"{a.lang}:{w.get('term', '').lower()}"
        if wid in seen:
            errors.append(f"{tag}: partide iki kez var")
        if wid in live:
            errors.append(f"{tag}: yayındaki sette zaten var")
        seen.add(wid)
        stem = w.get("term", "").lower()[:4]
        if stem and stem not in w.get("example", "").lower():
            warnings.append(f"{tag}: örnek cümlede kelime görünmüyor")

    print(f"{len(batch)} kelime · {a.lang} {a.level or 'seviye kelimede'}")
    for e in errors: print("HATA  ", e)
    for x in warnings: print("UYARI ", x)
    print("Sonuç:", "geçti" if not errors else f"{len(errors)} hata")
    sys.exit(1 if errors else 0)

if __name__ == "__main__":
    main()
