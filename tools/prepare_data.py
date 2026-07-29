#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
YDS Kelimelerim — web veri kaynağını iOS paketine dönüştürür.

Girdi  : tools/rawdata/ (web projesinin src/ klasöründen kopyalanır)
Çıktı  : Resources/Data/deck.json  — uygulamanın paketine gömülen tek dosya

Web'deki src/build.py ile AYNI kuralları uygular:
  * dosyalar ada göre sıralı okunur (words_1..4, phrasals_1)
  * terim küçük harfe indirgenerek yinelenenler atılır, ilk kayıt geçerlidir
  * ikinci örnek cümle examples2_* dosyalarından terime göre eşlenir
  * kart kimlikleri w0.. / p0.. biçiminde, web ile birebir aynı sırada üretilir

Kimliklerin aynı kalması önemli: kullanıcı hem siteyi hem uygulamayı
kullanıyorsa ilerlemesi ileride taşınabilir kalsın diye.
"""

from __future__ import annotations

import glob
import json
import os
import re
import sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "tools", "rawdata")
OUT_DIR = os.path.join(ROOT, "Resources", "Data")
OUT = os.path.join(OUT_DIR, "deck.json")

POS_VALID = {"n", "v", "adj", "adv", "phr"}


# ------------------------------------------------------------------
# Yükleme ve doğrulama
# ------------------------------------------------------------------
def load_rows(pattern: str, arity: int) -> tuple[list, list]:
    rows, errors = [], []
    for path in sorted(glob.glob(os.path.join(RAW, pattern))):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        for i, raw in enumerate(data):
            row = list(raw)
            loc = "%s[%d] %s" % (os.path.basename(path), i, row[0] if row else "?")
            if len(row) != arity:
                errors.append("%s: %d alan bekleniyordu, %d var" % (loc, arity, len(row)))
                continue
            if any(not str(x).strip() for x in row[:-1]):
                errors.append("%s: boş alan" % loc)
            if not isinstance(row[-1], int) or not 1 <= row[-1] <= 3:
                errors.append("%s: seviye 1-3 olmalı (%r)" % (loc, row[-1]))
            rows.append(row)
    return rows, errors


def dedupe(rows: list) -> tuple[list, list]:
    seen, out, dropped = set(), [], []
    for row in rows:
        key = str(row[0]).strip().lower()
        if key in seen:
            dropped.append(key)
            continue
        seen.add(key)
        out.append(row)
    return out, dropped


def load_examples2(pattern: str) -> dict:
    out: dict[str, str] = {}
    for path in sorted(glob.glob(os.path.join(RAW, pattern))):
        with open(path, encoding="utf-8") as fh:
            for k, v in json.load(fh).items():
                out.setdefault(k, v)
    return out


def stem_forms(word: str) -> list:
    """Sözcüğün çekimli hâllerini yakalayan gövde önekleri.
    Swift tarafındaki SentenceMatcher ile aynı kuralı uygular."""
    s = re.sub(r"[^a-zA-Z]", "", word).lower()
    if re.search(r"[^aeiou]y$", s):
        return [s[:-1] + "y", s[:-1] + "i"]
    if s.endswith("e") and len(s) > 3:
        return [s[:-1]]
    return [s]


def check_sentence(term: str, sentence: str, irregular: dict) -> str | None:
    head = re.sub(r"[^a-zA-Z]", "", term.split()[0]).lower()
    forms = stem_forms(head) + irregular.get(head, [])
    if len(head) > 3 and not any(f in sentence.lower() for f in forms):
        return "hedef ifade cümlede geçmiyor"
    if not sentence.strip().endswith((".", "!", "?")):
        return "cümle noktalama ile bitmiyor"
    return None


# ------------------------------------------------------------------
# Dönüştürme
# ------------------------------------------------------------------
def build() -> int:
    with open(os.path.join(RAW, "irregular.json"), encoding="utf-8") as fh:
        irregular = json.load(fh)

    words, w_err = load_rows("words_*.json", 6)
    phrasals, p_err = load_rows("phrasals_*.json", 5)
    errors = w_err + p_err

    words, w_drop = dedupe(words)
    phrasals, p_drop = dedupe(phrasals)

    ex2_w = load_examples2("examples2_words_*.json")
    ex2_p = load_examples2("examples2_phrasals_*.json")

    cards = []
    warnings = []

    for i, r in enumerate(words):
        term, pos, meaning, en, tr, level = r
        if pos not in POS_VALID:
            errors.append("kelime '%s': bilinmeyen tür '%s'" % (term, pos))
        en2 = (ex2_w.get(term) or "").strip()
        if not en2:
            errors.append("kelime '%s': ikinci örnek cümle eksik" % term)
        elif en2 == en.strip():
            errors.append("kelime '%s': ikinci cümle birincisiyle aynı" % term)
        for label, sentence in (("1. cümle", en), ("2. cümle", en2)):
            if not sentence:
                continue
            problem = check_sentence(term, sentence, irregular)
            if problem:
                warnings.append("kelime '%s' %s: %s" % (term, label, problem))
        cards.append({
            "id": "w%d" % i,
            "kind": "word",
            "term": term,
            "pos": pos,
            "meaning": meaning,
            "exampleEN": en,
            "exampleTR": tr,
            "exampleEN2": en2,
            "level": level,
        })

    for i, r in enumerate(phrasals):
        term, meaning, en, tr, level = r
        en2 = (ex2_p.get(term) or "").strip()
        if not en2:
            errors.append("phrasal '%s': ikinci örnek cümle eksik" % term)
        elif en2 == en.strip():
            errors.append("phrasal '%s': ikinci cümle birincisiyle aynı" % term)
        cards.append({
            "id": "p%d" % i,
            "kind": "phrasal",
            "term": term,
            "pos": "phr",
            "meaning": meaning,
            "exampleEN": en,
            "exampleTR": tr,
            "exampleEN2": en2,
            "level": level,
        })

    unknown = (set(ex2_w) - {r[0] for r in words}) | (set(ex2_p) - {r[0] for r in phrasals})
    for u in sorted(unknown):
        errors.append("'%s' için ikinci cümle var ama listede böyle bir kayıt yok" % u)

    payload = {
        "version": 1,
        "generatedAt": date.today().isoformat(),
        "wordCount": len(words),
        "phrasalCount": len(phrasals),
        "irregular": irregular,
        "cards": cards,
    }

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(OUT) / 1024
    print("deck.json yazıldı — %d kelime + %d phrasal = %d kart, %.1f KB"
          % (len(words), len(phrasals), len(cards), size_kb))
    if w_drop or p_drop:
        print("yinelenen atıldı: %s" % ", ".join(w_drop + p_drop))
    for w in warnings:
        print("UYARI: %s" % w)
    if errors:
        print("\n%d HATA:" % len(errors), file=sys.stderr)
        for e in errors:
            print("  - %s" % e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(build())
