#!/usr/bin/env python3
"""Translate missing emergency-guide Markdown with Codex OAuth and strict validation."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
from pathlib import Path
import re
import sys
import time
from typing import Iterable

import httpx

ROOT = Path(__file__).resolve().parents[1]
GUIDES_DIR = ROOT / "assets" / "emergency_guides"
ENDPOINT = "https://chatgpt.com/backend-api/codex/responses"
LANGUAGE_NAMES = {
    "en": "professional US English",
    "pt": "professional Brazilian Portuguese",
    "fr": "professional neutral French",
    "zh": "professional Simplified Chinese",
    "ja": "professional Japanese",
    "ht": "professional Haitian Creole",
}
URL_RE = re.compile(r"https?://[^\s)>\]}]+")
INVARIANT_UNIT = (
    r"mL/kg|L/min|mmHg|km/h|m/s|mcg|µg|mg|kg|mL|ml|dL|"
    r"bpm|rpm|min|cm|mm|km|°[CF]|%|L|g|m|h|s|V"
)
NUMBER_RE = re.compile(
    rf"\d+(?:[.,]\d+)?(?:\s?(?:{INVARIANT_UNIT})(?![A-Za-z\u00C0-\u024F]))?"
)
MACHINE_METADATA_RE = re.compile(
    r"^(priority|mode|category):[ \t]*(.*?)[ \t]*$", re.MULTILINE
)
SOURCE_NEGATION_RE = re.compile(
    r"\b(?:no|nunca|jamás|sin|evita|evite|evitar|prohibido)\b",
    re.IGNORECASE,
)
HEADING_RE = re.compile(r"^#{1,6}\s+", re.MULTILINE)
BULLET_RE = re.compile(r"^\s*[-*+]\s+", re.MULTILINE)
ORDERED_RE = re.compile(r"^\s*\d+[.)]\s+", re.MULTILINE)
MARKDOWN_PREFIX_RE = re.compile(
    r"^([ \t]*(?:#{1,6}|[-*+]|\d+[.)])[ \t]+)", re.MULTILINE
)


def extract_json_object(raw: str) -> dict[str, str]:
    text = raw.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    parsed = json.loads(text)
    if not isinstance(parsed, dict) or not all(
        isinstance(key, str) and isinstance(value, str)
        for key, value in parsed.items()
    ):
        raise ValueError("response must be a JSON object mapping slugs to Markdown strings")
    return parsed


def _tokens(pattern: re.Pattern[str], text: str) -> list[str]:
    return sorted(match.group(0).strip() for match in pattern.finditer(text))


def mask_numeric_literals(text: str) -> tuple[str, list[str]]:
    literals: list[str] = []

    def replace(match: re.Match[str]) -> str:
        index = len(literals)
        literals.append(match.group(0).strip())
        return f"__KEEP_NUM_{index}__"

    return NUMBER_RE.sub(replace, text), literals


def restore_numeric_literals(slug: str, text: str, literals: list[str]) -> str:
    restored = text
    for index, literal in enumerate(literals):
        placeholder = f"__KEEP_NUM_{index}__"
        if restored.count(placeholder) != 1:
            raise ValueError(f"{slug}: missing numeric placeholder {placeholder}")
        restored = restored.replace(placeholder, literal)
    if "__KEEP_NUM_" in restored:
        raise ValueError(f"{slug}: unexpected numeric placeholder")
    return restored


JAPANESE_REDUNDANT_UNIT_GLOSSES = (
    ("mL/kg", "ミリリットル毎キログラム"),
    ("km/h", "キロメートル毎時"),
    ("L/min", "リットル毎分"),
    ("min", "分"),
    ("mL", "ミリリットル"),
    ("ml", "ミリリットル"),
    ("km", "キロメートル"),
    ("cm", "センチメートル"),
    ("mm", "ミリメートル"),
    ("kg", "キログラム"),
    ("mg", "ミリグラム"),
    ("L", "リットル"),
    ("m", "メートル"),
    ("h", "時間"),
    ("s", "秒"),
    ("g", "グラム"),
    ("%", "パーセント"),
)


def strip_redundant_unit_glosses(text: str, language: str) -> str:
    if language != "ja":
        return text
    normalized = text
    for unit, gloss in JAPANESE_REDUNDANT_UNIT_GLOSSES:
        pattern = rf"(\d+(?:[.,]\d+)?\s?{re.escape(unit)}){re.escape(gloss)}"
        normalized = re.sub(pattern, r"\1", normalized)
    return normalized


def _alpha_index(index: int) -> str:
    value = index
    encoded = ""
    while True:
        value, remainder = divmod(value, 26)
        encoded = chr(ord("A") + remainder) + encoded
        if value == 0:
            return encoded
        value -= 1


def mask_markdown_structure(text: str) -> tuple[str, list[str]]:
    prefixes: list[str] = []

    def replace(match: re.Match[str]) -> str:
        index = len(prefixes)
        prefixes.append(match.group(1))
        return f"__KEEP_MD_{_alpha_index(index)}__"

    return MARKDOWN_PREFIX_RE.sub(replace, text), prefixes


def restore_markdown_structure(slug: str, text: str, prefixes: list[str]) -> str:
    restored = text
    for index, prefix in enumerate(prefixes):
        placeholder = f"__KEEP_MD_{_alpha_index(index)}__"
        if restored.count(placeholder) != 1:
            raise ValueError(f"{slug}: missing Markdown structure placeholder {placeholder}")
        restored = restored.replace(placeholder, prefix)
    if "__KEEP_MD_" in restored:
        raise ValueError(f"{slug}: unexpected Markdown structure placeholder")
    return restored


def mask_machine_metadata(text: str) -> tuple[str, list[str]]:
    values: list[str] = []

    def replace(match: re.Match[str]) -> str:
        index = len(values)
        values.append(match.group(2))
        return f"{match.group(1)}: __KEEP_META_{index}__"

    return MACHINE_METADATA_RE.sub(replace, text), values


def restore_machine_metadata(slug: str, text: str, values: list[str]) -> str:
    restored = text
    for index, value in enumerate(values):
        placeholder = f"__KEEP_META_{index}__"
        if restored.count(placeholder) != 1:
            raise ValueError(f"{slug}: missing machine metadata placeholder {placeholder}")
        restored = restored.replace(placeholder, value)
    if "__KEEP_META_" in restored:
        raise ValueError(f"{slug}: unexpected machine metadata placeholder")
    return restored


def _machine_metadata(text: str) -> dict[str, str]:
    return {
        match.group(1): match.group(2)
        for match in MACHINE_METADATA_RE.finditer(text)
    }


def mask_negation_anchors(text: str) -> tuple[str, int]:
    anchored: list[str] = []
    count = 0
    for line in text.splitlines(keepends=True):
        content = line.rstrip("\r\n")
        ending = line[len(content) :]
        if SOURCE_NEGATION_RE.search(content):
            content += f" __KEEP_NEG_{count}__"
            count += 1
        anchored.append(content + ending)
    return "".join(anchored), count


def restore_negation_anchors(slug: str, text: str, count: int) -> str:
    restored = text
    for index in range(count):
        placeholder = f"__KEEP_NEG_{index}__"
        if restored.count(placeholder) != 1:
            raise ValueError(f"{slug}: missing negation anchor {placeholder}")
        restored = restored.replace(placeholder, "")
    if "__KEEP_NEG_" in restored:
        raise ValueError(f"{slug}: unexpected negation anchor")
    return re.sub(r"[ \t]+$", "", restored, flags=re.MULTILINE)


def validate_translation(slug: str, source: str, translated: str, language: str) -> list[str]:
    errors: list[str] = []
    if not translated.strip():
        return [f"{slug}: empty translation"]
    if language != "es" and translated.strip() == source.strip():
        errors.append(f"{slug}: body is unchanged from Spanish")
    if len(HEADING_RE.findall(source)) != len(HEADING_RE.findall(translated)):
        errors.append(f"{slug}: Markdown heading count changed")
    if len(BULLET_RE.findall(source)) != len(BULLET_RE.findall(translated)):
        errors.append(f"{slug}: Markdown bullet count changed")
    if len(ORDERED_RE.findall(source)) != len(ORDERED_RE.findall(translated)):
        errors.append(f"{slug}: Markdown ordered-list count changed")
    if source.count("```") != translated.count("```"):
        errors.append(f"{slug}: Markdown code-fence count changed")
    source_urls = sorted(URL_RE.findall(source))
    translated_urls = sorted(URL_RE.findall(translated))
    if source_urls != translated_urls:
        errors.append(f"{slug}: source URL set changed")
    source_metadata = _machine_metadata(source)
    translated_metadata = _machine_metadata(translated)
    if source_metadata != translated_metadata:
        errors.append(
            f"{slug}: machine metadata changed: "
            f"{source_metadata!r} != {translated_metadata!r}"
        )
    source_numbers = _tokens(NUMBER_RE, source)
    translated_numbers = _tokens(NUMBER_RE, translated)
    if source_numbers != translated_numbers:
        errors.append(
            f"{slug}: numeric/unit tokens changed: {source_numbers!r} != {translated_numbers!r}"
        )
    return errors


def _chunks(items: list[str], size: int) -> Iterable[list[str]]:
    for start in range(0, len(items), size):
        yield items[start : start + size]


def _token() -> str:
    hermes_home = Path(os.environ.get("HERMES_HOME", "~/.hermes")).expanduser()
    auth = json.loads((hermes_home / "auth.json").read_text(encoding="utf-8"))
    return auth["credential_pool"]["openai-codex"][0]["access_token"]


def _find_text(obj: object) -> list[str]:
    found: list[str] = []
    if isinstance(obj, dict):
        if obj.get("type") in {"output_text", "text"} and isinstance(obj.get("text"), str):
            found.append(obj["text"])
        for value in obj.values():
            found.extend(_find_text(value))
    elif isinstance(obj, list):
        for value in obj:
            found.extend(_find_text(value))
    return found


def request_translation(language: str, sources: dict[str, str], feedback: str = "") -> dict[str, str]:
    target_name = LANGUAGE_NAMES[language]
    language_specific = (
        " In Japanese, when the Spanish source writes a quantity as a word, use Japanese words or kanji "
        "such as 一人, never introduce an Arabic digit such as 1人."
        if language == "ja"
        else ""
    )
    instructions = (
        "You are a safety-critical medical and wilderness-survival translator. "
        f"Translate Spanish Markdown into {target_name}. Preserve clinical meaning, every negation, "
        "imperative, order, numeric literal, unit, URL, Markdown heading/list/table/code structure, and source citation. "
        "Do not add advice, omit warnings, summarize, soften, or alter procedures. Keep slugs unchanged. "
        "In YAML frontmatter, translate title and keywords only. Copy priority, mode, and category values exactly. "
        "Return only one valid JSON object mapping each requested slug to the complete translated Markdown string. "
        "Each __KEEP_NEG_0__ token marks a line whose negation must remain semantically negative. "
        "Do not convert list markers to another style and do not invent unit abbreviations. "
        "Tokens such as __KEEP_NUM_0__, __KEEP_META_0__, __KEEP_NEG_0__, and __KEEP_MD_A__ are immutable: "
        "copy every one exactly once."
        + language_specific
    )
    prompt = json.dumps(sources, ensure_ascii=False)
    if feedback:
        prompt += "\nPrevious output failed validation. Correct all of these issues:\n" + feedback
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
        "input": [{"type": "message", "role": "user", "content": [{"type": "input_text", "text": prompt}]}],
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
                if event.get("type") == "response.output_text.delta" and isinstance(event.get("delta"), str):
                    deltas.append(event["delta"])
                elif event.get("type") in {"response.completed", "response.output_item.done"}:
                    fallback.extend(_find_text(event))
    text = "".join(deltas).strip() or "\n".join(fallback).strip()
    if not text:
        raise RuntimeError("translation endpoint returned no text")
    return extract_json_object(text)


def translate_batch(language: str, slugs: list[str], *, dry_run: bool) -> None:
    sources = {
        slug: (GUIDES_DIR / "es" / f"{slug}.md").read_text(encoding="utf-8")
        for slug in slugs
    }
    masked_sources: dict[str, str] = {}
    markdown_prefixes: dict[str, list[str]] = {}
    numeric_literals: dict[str, list[str]] = {}
    machine_metadata: dict[str, list[str]] = {}
    negation_anchors: dict[str, int] = {}
    for slug, source in sources.items():
        structure_masked, markdown_prefixes[slug] = mask_markdown_structure(source)
        numeric_masked, numeric_literals[slug] = mask_numeric_literals(structure_masked)
        metadata_masked, machine_metadata[slug] = mask_machine_metadata(numeric_masked)
        masked_sources[slug], negation_anchors[slug] = mask_negation_anchors(metadata_masked)

    pending = list(slugs)
    feedback = ""
    last_errors: dict[str, list[str]] = {}
    for attempt in range(1, 4):
        try:
            raw_translations = request_translation(
                language,
                {slug: masked_sources[slug] for slug in pending},
                feedback,
            )
        except (httpx.HTTPError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
            if attempt == 3:
                raise RuntimeError(
                    f"{language}/{pending}: transport/parse failed after 3 attempts: {exc}"
                ) from exc
            time.sleep(2**attempt)
            continue

        last_errors = {}
        completed: list[str] = []
        for slug in pending:
            if slug not in raw_translations:
                last_errors[slug] = [f"{slug}: missing from model response"]
                continue
            try:
                negation_restored = restore_negation_anchors(
                    slug,
                    raw_translations[slug],
                    negation_anchors[slug],
                )
                metadata_restored = restore_machine_metadata(
                    slug,
                    negation_restored,
                    machine_metadata[slug],
                )
                numeric_restored = restore_numeric_literals(
                    slug,
                    metadata_restored,
                    numeric_literals[slug],
                )
                numeric_restored = strip_redundant_unit_glosses(
                    numeric_restored,
                    language,
                )
                restored = restore_markdown_structure(
                    slug,
                    numeric_restored,
                    markdown_prefixes[slug],
                )
            except ValueError as exc:
                last_errors[slug] = [str(exc)]
                continue

            errors = validate_translation(slug, sources[slug], restored, language)
            if errors:
                last_errors[slug] = errors
                continue

            if dry_run:
                print(f"VALID {language}: {slug}", flush=True)
            else:
                target_dir = GUIDES_DIR / language
                target_dir.mkdir(parents=True, exist_ok=True)
                target = target_dir / f"{slug}.md"
                temporary = target.with_suffix(".md.tmp")
                temporary.write_text(restored.rstrip() + "\n", encoding="utf-8")
                temporary.replace(target)
                print(f"WROTE {language}: {slug}", flush=True)
            completed.append(slug)

        pending = [slug for slug in pending if slug not in completed]
        if not pending:
            return

        feedback = "\n".join(
            error
            for slug in pending
            for error in last_errors.get(
                slug, [f"{slug}: unknown validation failure"]
            )
        )
        if attempt < 3:
            time.sleep(2**attempt)

    raise RuntimeError(
        f"{language}/{pending}: validation failed after 3 attempts:\n{feedback}"
    )


def translate_resilient_batch(
    language: str,
    slugs: list[str],
    *,
    dry_run: bool,
) -> None:
    """Retry each guide alone when a multi-guide response remains invalid."""
    try:
        translate_batch(language, slugs, dry_run=dry_run)
        return
    except (RuntimeError, httpx.HTTPError):
        if len(slugs) == 1:
            raise

    failures: list[str] = []
    for slug in slugs:
        try:
            translate_batch(language, [slug], dry_run=dry_run)
        except (RuntimeError, httpx.HTTPError) as exc:
            failures.append(f"{slug}: {exc}")
    if failures:
        raise RuntimeError(
            f"{language}: individual fallback failed for {len(failures)} guide(s):\n"
            + "\n".join(failures)
        )


def needs_translation(
    source_path: Path,
    target_path: Path,
    language: str,
    *,
    force: bool,
    repair_invalid: bool,
) -> bool:
    if force or not target_path.is_file():
        return True
    if not repair_invalid:
        return False
    return bool(
        validate_translation(
            source_path.stem,
            source_path.read_text(encoding="utf-8"),
            target_path.read_text(encoding="utf-8"),
            language,
        )
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--languages", nargs="+", choices=sorted(LANGUAGE_NAMES), default=sorted(LANGUAGE_NAMES))
    parser.add_argument("--slugs", nargs="*", help="Optional exact subset of Spanish guide slugs")
    parser.add_argument("--batch-size", type=int, default=3)
    parser.add_argument("--workers", type=int, default=1)
    parser.add_argument("--force", action="store_true")
    parser.add_argument(
        "--repair-invalid",
        action="store_true",
        help="Regenerate existing files that fail structural or numeric validation",
    )
    parser.add_argument("--dry-run", action="store_true", help="Validate model output without writing files")
    args = parser.parse_args()
    if args.batch_size < 1 or args.batch_size > 5:
        parser.error("--batch-size must be between 1 and 5")
    if args.workers < 1 or args.workers > 3:
        parser.error("--workers must be between 1 and 3")

    canonical = sorted(path.stem for path in (GUIDES_DIR / "es").glob("*.md"))
    selected = args.slugs or canonical
    unknown = sorted(set(selected) - set(canonical))
    if unknown:
        parser.error(f"unknown slugs: {unknown}")

    tasks: list[tuple[str, list[str]]] = []
    for language in args.languages:
        pending = [
            slug
            for slug in selected
            if needs_translation(
                GUIDES_DIR / "es" / f"{slug}.md",
                GUIDES_DIR / language / f"{slug}.md",
                language,
                force=args.force,
                repair_invalid=args.repair_invalid,
            )
        ]
        print(f"{language}: pending={len(pending)}", flush=True)
        tasks.extend((language, batch) for batch in _chunks(pending, args.batch_size))

    failures: list[str] = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(
                translate_resilient_batch,
                language,
                batch,
                dry_run=args.dry_run,
            ): (
                language,
                batch,
            )
            for language, batch in tasks
        }
        for future in as_completed(futures):
            language, batch = futures[future]
            try:
                future.result()
            except (RuntimeError, httpx.HTTPError) as exc:
                print(f"ERROR {exc}", file=sys.stderr, flush=True)
                failures.extend(f"{language}/{slug}" for slug in batch)
    if failures:
        print(f"FAILED {len(failures)}: {', '.join(failures)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
