#!/usr/bin/env python3
"""Translate all emergency tutorial captions and atomically rewrite the Dart registry."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
import re
import time

import httpx

from translate_emergency_guides import ENDPOINT, _find_text, _token

ROOT = Path(__file__).resolve().parents[1]
DART_FILE = ROOT / "lib/modules/emergency/emergency_guide_tutorials.dart"
CACHE_FILE = ROOT / ".hermes/tutorial_caption_translations.json"
TARGET_LANGUAGES = ("pt", "fr", "zh", "ja", "ht")
ALL_LANGUAGES = ("es", "en", *TARGET_LANGUAGES)
# Unlike the Markdown validator's NUMBER_RE, caption numbers may be directly
# adjacent to CJK characters (for example, 煮沸2分钟). Exclude only ASCII word
# characters so placeholders such as __KEEP_NUM_0__ are not mistaken for data.
CAPTION_NUMBER_RE = re.compile(
    r"(?<![A-Za-z0-9_])\d+(?:[.,]\d+)?"
    r"(?:\s?(?:%|°[CF]|kg|mg|mcg|µg|mL|ml|dL|L|mm|cm|km|m))?(?![A-Za-z])"
)
CAPTION_NEGATION_RE = re.compile(
    r"\b(?:do\s+not|must\s+not|cannot|can't|don't|not|never|without|avoid|"
    r"no|nunca|jamás|sin|evita)\b",
    re.IGNORECASE,
)
ENTRY_RE = re.compile(
    r'^(?P<entry_indent>[ \t]*)"(?P<slug>[^"]+)": EmergencyGuideTutorial\('
    r'(?P<body>.*?)(?=^[ \t]*"[^"]+": EmergencyGuideTutorial\(|^[ \t]*};)',
    re.MULTILINE | re.DOTALL,
)
STEP_RE = re.compile(
    r'(?P<indent>^[ \t]*)EmergencyGuideTutorialStep\(\s*'
    r'number:\s*(?P<number>\d+),\s*'
    r'captionEs:\s*(?P<es>"(?:[^"\\]|\\.)*"),\s*'
    r'captionEn:\s*(?P<en>"(?:[^"\\]|\\.)*"),\s*'
    r'\)',
    re.MULTILINE | re.DOTALL,
)
LOCALIZED_CAPTIONS_RE = re.compile(
    r"captions:\s*\{(?P<body>.*?)^[ \t]*\},",
    re.MULTILINE | re.DOTALL,
)


@dataclass(frozen=True)
class CaptionPair:
    slug: str
    number: int
    es: str
    en: str

    @property
    def key(self) -> str:
        return f"{self.slug}:{self.number}"


def _decode_dart_string(literal: str) -> str:
    return json.loads(literal)


def dart_string(value: str) -> str:
    encoded = json.dumps(value, ensure_ascii=False)
    return encoded.replace("$", r"\$")


def parse_caption_pairs(text: str) -> list[CaptionPair]:
    rows: list[CaptionPair] = []
    for entry in ENTRY_RE.finditer(text):
        slug = entry.group("slug")
        for step in STEP_RE.finditer(entry.group("body")):
            rows.append(
                CaptionPair(
                    slug=slug,
                    number=int(step.group("number")),
                    es=_decode_dart_string(step.group("es")),
                    en=_decode_dart_string(step.group("en")),
                )
            )
    keys = [row.key for row in rows]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate slug/step keys in Dart registry")
    return rows


def is_fully_localized_registry(text: str, *, expected_steps: int = 201) -> bool:
    maps = LOCALIZED_CAPTIONS_RE.findall(text)
    if len(maps) != expected_steps:
        return False
    expected = list(ALL_LANGUAGES)
    for body in maps:
        keys = re.findall(r'^\s*"([a-z]+)":', body, re.MULTILINE)
        if keys != expected:
            return False
    return "captionEs:" not in text and "captionEn:" not in text


def _parse_response_json(raw: str) -> dict[str, dict[str, str]]:
    text = raw.strip()
    if text.startswith("```"):
        lines = text.splitlines()[1:]
        if lines and lines[-1].strip() == "```":
            lines.pop()
        text = "\n".join(lines).strip()
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError("caption response is not an object")
    result: dict[str, dict[str, str]] = {}
    for key, value in data.items():
        if not isinstance(key, str) or not isinstance(value, dict):
            raise ValueError("caption response must map string keys to language objects")
        translated = {str(lang): str(caption) for lang, caption in value.items()}
        result[key] = translated
    return result


def _numeric_tokens(text: str) -> list[str]:
    return sorted(match.group(0).strip() for match in CAPTION_NUMBER_RE.finditer(text))


def _requires_negation_anchor(row: CaptionPair) -> bool:
    return bool(CAPTION_NEGATION_RE.search(row.es) or CAPTION_NEGATION_RE.search(row.en))


def mask_caption_pair(row: CaptionPair) -> dict[str, str]:
    es_numbers = [match.group(0).strip() for match in CAPTION_NUMBER_RE.finditer(row.es)]
    en_numbers = [match.group(0).strip() for match in CAPTION_NUMBER_RE.finditer(row.en)]
    if es_numbers != en_numbers:
        raise ValueError(
            f"{row.key}: ES/EN numeric literals differ: {es_numbers!r} != {en_numbers!r}"
        )

    def mask(text: str) -> str:
        index = 0

        def replace(_match: re.Match[str]) -> str:
            nonlocal index
            placeholder = f"__KEEP_NUM_{index}__"
            index += 1
            return placeholder

        masked = CAPTION_NUMBER_RE.sub(replace, text)
        if index != len(es_numbers):
            raise ValueError(f"{row.key}: failed to mask every numeric literal")
        if _requires_negation_anchor(row):
            masked += " __KEEP_NEG__"
        return masked

    return {"es": mask(row.es), "en": mask(row.en)}


def restore_numeric_literals(
    row: CaptionPair,
    translated: dict[str, str],
) -> dict[str, str]:
    numbers = [match.group(0).strip() for match in CAPTION_NUMBER_RE.finditer(row.es)]
    restored: dict[str, str] = {}
    for language, caption in translated.items():
        value = caption
        for index, number in enumerate(numbers):
            placeholder = f"__KEEP_NUM_{index}__"
            if value.count(placeholder) != 1:
                raise ValueError(
                    f"{row.key}/{language}: missing numeric placeholder {placeholder}"
                )
            value = value.replace(placeholder, number)
        if "__KEEP_NUM_" in value:
            raise ValueError(f"{row.key}/{language}: unexpected numeric placeholder")
        if _requires_negation_anchor(row):
            if value.count("__KEEP_NEG__") != 1:
                raise ValueError(
                    f"{row.key}/{language}: missing negation anchor __KEEP_NEG__"
                )
            value = value.replace("__KEEP_NEG__", "").strip()
        elif "__KEEP_NEG__" in value:
            raise ValueError(f"{row.key}/{language}: unexpected negation anchor")
        restored[language] = value
    return restored


def validate_caption_translation(row: CaptionPair, translated: dict[str, str]) -> list[str]:
    errors: list[str] = []
    if set(translated) != set(TARGET_LANGUAGES):
        errors.append(
            f"{row.key}: expected languages {sorted(TARGET_LANGUAGES)}, got {sorted(translated)}"
        )
        return errors
    source_numbers = _numeric_tokens(row.es)
    for language in TARGET_LANGUAGES:
        caption = translated[language].strip()
        if not caption:
            errors.append(f"{row.key}/{language}: empty")
            continue
        if caption in {row.es.strip(), row.en.strip()}:
            errors.append(f"{row.key}/{language}: unchanged source caption")
        if _numeric_tokens(caption) != source_numbers:
            errors.append(
                f"{row.key}/{language}: numeric tokens changed "
                f"{source_numbers!r} != {_numeric_tokens(caption)!r}"
            )
    return errors


def request_batch(rows: list[CaptionPair], feedback: str = "") -> dict[str, dict[str, str]]:
    input_data = {row.key: mask_caption_pair(row) for row in rows}
    prompt = json.dumps(input_data, ensure_ascii=False)
    if feedback:
        prompt += "\nCorrect every validation problem from the previous response:\n" + feedback
    instructions = (
        "Translate concise safety-critical emergency and wilderness tutorial captions into Brazilian Portuguese (pt), "
        "neutral French (fr), Simplified Chinese (zh), Japanese (ja), and Haitian Creole (ht). "
        "Use both Spanish and English sources to disambiguate. Preserve every number, unit, negation, chronology, "
        "medical technique, and survival action exactly. Do not add or remove advice. Return only valid JSON shaped "
        "as {\"slug:number\": {\"pt\": \"...\", \"fr\": \"...\", \"zh\": \"...\", \"ja\": \"...\", \"ht\": \"...\"}}. "
        "Tokens such as __KEEP_NUM_0__ are immutable numeric placeholders: copy every one exactly once into every target caption. "
        "The token __KEEP_NEG__ is an immutable safety-negation anchor: copy it exactly once into every target caption and preserve the prohibition. "
        "Never introduce an ASCII digit that is not present as a __KEEP_NUM_n__ token. Express lexical concepts without digits; "
        "for example, translate ground floor into Japanese as 地上階, never 1階."
    )
    headers = {
        "User-Agent": "codex_cli_rs/0.0.0 (Hermes Agent)",
        "originator": "codex_cli_rs",
        "Accept": "text/event-stream",
        "Authorization": f"Bearer {_token()}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "gpt-5.5",
        "store": False,
        "instructions": instructions,
        "input": [
            {
                "type": "message",
                "role": "user",
                "content": [{"type": "input_text", "text": prompt}],
            }
        ],
        "stream": True,
    }
    deltas: list[str] = []
    fallback: list[str] = []
    with httpx.Client(timeout=httpx.Timeout(600.0), headers=headers) as http:
        with http.stream("POST", ENDPOINT, json=payload) as response:
            response.raise_for_status()
            for line in response.iter_lines():
                if not line or not line.startswith("data: "):
                    continue
                raw = line[6:]
                if raw == "[DONE]":
                    break
                event = json.loads(raw)
                if event.get("type") == "response.output_text.delta" and isinstance(
                    event.get("delta"), str
                ):
                    deltas.append(event["delta"])
                elif event.get("type") in {"response.completed", "response.output_item.done"}:
                    fallback.extend(_find_text(event))
    text = "".join(deltas).strip() or "\n".join(fallback).strip()
    if not text:
        raise RuntimeError("caption endpoint returned no text")
    return _parse_response_json(text)


def translate_batch(rows: list[CaptionPair]) -> dict[str, dict[str, str]]:
    feedback = ""
    for attempt in range(1, 4):
        try:
            masked_translations = request_batch(rows, feedback)
        except (httpx.HTTPError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
            if attempt == 3:
                raise RuntimeError(f"caption transport/parse failed after 3 attempts: {exc}") from exc
            time.sleep(2**attempt)
            continue
        errors: list[str] = []
        expected = {row.key for row in rows}
        if set(masked_translations) != expected:
            errors.append(
                f"keys changed: expected {sorted(expected)}, got {sorted(masked_translations)}"
            )
        by_key = {row.key: row for row in rows}
        translated: dict[str, dict[str, str]] = {}
        for key, value in masked_translations.items():
            if key in by_key:
                try:
                    restored = restore_numeric_literals(by_key[key], value)
                except ValueError as exc:
                    errors.append(str(exc))
                    continue
                translated[key] = restored
                errors.extend(validate_caption_translation(by_key[key], restored))
        if not errors:
            return translated
        feedback = "\n".join(errors)
        if attempt < 3:
            time.sleep(2**attempt)
    raise RuntimeError(f"caption validation failed after 3 attempts:\n{feedback}")


def translate_resilient_batch(rows: list[CaptionPair]) -> dict[str, dict[str, str]]:
    """Translate a batch, isolating rows if the model cross-contaminates them."""
    try:
        return translate_batch(rows)
    except RuntimeError:
        if len(rows) == 1:
            raise
        midpoint = len(rows) // 2
        translated = translate_resilient_batch(rows[:midpoint])
        translated.update(translate_resilient_batch(rows[midpoint:]))
        return translated


def rewrite_caption_pairs(text: str, translations: dict[str, dict[str, str]]) -> str:
    rows = parse_caption_pairs(text)
    missing = sorted(row.key for row in rows if row.key not in translations)
    if missing:
        raise ValueError(f"missing translations for {len(missing)} steps: {missing[:10]}")
    row_by_key = {row.key: row for row in rows}

    def rewrite_entry(entry_match: re.Match[str]) -> str:
        entry_indent = entry_match.group("entry_indent")
        slug = entry_match.group("slug")
        body = entry_match.group("body")

        def rewrite_step(step_match: re.Match[str]) -> str:
            number = int(step_match.group("number"))
            key = f"{slug}:{number}"
            row = row_by_key[key]
            translated = translations[key]
            indent = step_match.group("indent")
            inner = indent + "  "
            map_indent = inner + "  "
            lines = [
                f"{indent}EmergencyGuideTutorialStep(",
                f"{inner}number: {number},",
                f"{inner}captions: {{",
                f'{map_indent}"es": {dart_string(row.es)},',
                f'{map_indent}"en": {dart_string(row.en)},',
            ]
            for language in TARGET_LANGUAGES:
                lines.append(
                    f'{map_indent}"{language}": {dart_string(translated[language])},'
                )
            lines.extend([f"{inner}}},", f"{indent})"])
            return "\n".join(lines)

        rewritten_body, count = STEP_RE.subn(rewrite_step, body)
        expected_count = sum(row.slug == slug for row in rows)
        if count != expected_count:
            raise ValueError(f"{slug}: rewrote {count} of {expected_count} steps")
        return f'{entry_indent}"{slug}": EmergencyGuideTutorial(' + rewritten_body

    rewritten, entry_count = ENTRY_RE.subn(rewrite_entry, text)
    slug_count = len({row.slug for row in rows})
    if entry_count != slug_count:
        raise ValueError(f"rewrote {entry_count} of {slug_count} tutorial entries")
    if "captionEs:" in rewritten or "captionEn:" in rewritten:
        raise ValueError("legacy caption fields remain after rewrite")
    return rewritten


def _write_cache(cache: dict[str, dict[str, str]]) -> None:
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = CACHE_FILE.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(cache, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(CACHE_FILE)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--batch-size", type=int, default=10)
    parser.add_argument("--force", action="store_true", help="Discard cached translations")
    args = parser.parse_args()
    if args.batch_size < 1 or args.batch_size > 15:
        parser.error("--batch-size must be between 1 and 15")

    text = DART_FILE.read_text(encoding="utf-8")
    rows = parse_caption_pairs(text)
    if not rows and is_fully_localized_registry(text):
        print(f"already localized: {DART_FILE} contains 201 complete caption maps")
        return 0
    if len(rows) != 201:
        raise SystemExit(f"Expected 201 legacy caption pairs, found {len(rows)}")
    cache: dict[str, dict[str, str]] = {}
    if CACHE_FILE.is_file() and not args.force:
        cache = json.loads(CACHE_FILE.read_text(encoding="utf-8"))
    by_key = {row.key: row for row in rows}
    valid_cache: dict[str, dict[str, str]] = {}
    for key, translated in cache.items():
        if key in by_key and not validate_caption_translation(by_key[key], translated):
            valid_cache[key] = translated
    cache = valid_cache
    pending = [row for row in rows if row.key not in cache]
    print(f"captions total={len(rows)} cached={len(cache)} pending={len(pending)}", flush=True)
    for start in range(0, len(pending), args.batch_size):
        batch = pending[start : start + args.batch_size]
        translated = translate_resilient_batch(batch)
        cache.update(translated)
        _write_cache(cache)
        print(f"translated={len(cache)}/{len(rows)}", flush=True)

    rewritten = rewrite_caption_pairs(text, cache)
    temporary = DART_FILE.with_suffix(".dart.tmp")
    temporary.write_text(rewritten, encoding="utf-8")
    temporary.replace(DART_FILE)
    print(f"rewrote {DART_FILE} with {len(rows)} localized steps")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
