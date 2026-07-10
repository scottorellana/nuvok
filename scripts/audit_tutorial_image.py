#!/usr/bin/env python3
"""Audit one tutorial image/contact sheet with Codex OAuth multimodal input."""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
from pathlib import Path
import sys
import time

import httpx

ENDPOINT = "https://chatgpt.com/backend-api/codex/responses"


def find_text(obj: object) -> list[str]:
    found: list[str] = []
    if isinstance(obj, dict):
        if obj.get("type") in {"output_text", "text"} and isinstance(obj.get("text"), str):
            found.append(obj["text"])
        for value in obj.values():
            found.extend(find_text(value))
    elif isinstance(obj, list):
        for value in obj:
            found.extend(find_text(value))
    return found


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image")
    parser.add_argument("prompt")
    args = parser.parse_args()

    image_path = Path(args.image).expanduser().resolve()
    if not image_path.is_file():
        parser.error(f"image not found: {image_path}")
    mime = mimetypes.guess_type(image_path.name)[0] or "image/png"
    encoded = base64.b64encode(image_path.read_bytes()).decode("ascii")

    hermes_home = Path(os.environ.get("HERMES_HOME", "~/.hermes")).expanduser()
    auth = json.loads((hermes_home / "auth.json").read_text())
    token = auth["credential_pool"]["openai-codex"][0]["access_token"]
    headers = {
        "User-Agent": "codex_cli_rs/0.0.0 (Hermes Agent)",
        "originator": "codex_cli_rs",
        "Accept": "text/event-stream",
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "gpt-5.5",
        "store": False,
        "instructions": (
            "You are a strict visual QA auditor for offline emergency training illustrations. "
            "Inspect the supplied image pixels. Reject ambiguity, unsafe technique, merged anatomy, "
            "extra people or limbs, ghosting, missing equipment, inconsistent panels, or unclear cause and effect. "
            "Never assume details that are not visibly present. Return concise JSON only."
        ),
        "input": [{
            "type": "message",
            "role": "user",
            "content": [
                {"type": "input_text", "text": args.prompt},
                {"type": "input_image", "image_url": f"data:{mime};base64,{encoded}"},
            ],
        }],
        "stream": True,
    }

    for attempt in range(1, 4):
        deltas: list[str] = []
        fallback_text: list[str] = []
        try:
            with httpx.Client(timeout=httpx.Timeout(300.0), headers=headers) as http:
                with http.stream("POST", ENDPOINT, json=payload) as response:
                    response.raise_for_status()
                    for line in response.iter_lines():
                        if not line or not line.startswith("data: "):
                            continue
                        raw = line[6:]
                        if raw == "[DONE]":
                            break
                        event = json.loads(raw)
                        if event.get("type") == "response.output_text.delta":
                            delta = event.get("delta")
                            if isinstance(delta, str):
                                deltas.append(delta)
                        elif event.get("type") in {
                            "response.completed",
                            "response.output_item.done",
                        }:
                            fallback_text.extend(find_text(event))
        except httpx.HTTPError as exc:
            if attempt == 3:
                print(f"audit transport failed after 3 attempts: {exc}", file=sys.stderr)
                return 1
            delay = 2 ** attempt
            print(
                f"audit transport attempt {attempt} failed ({exc}); retrying in {delay}s",
                file=sys.stderr,
            )
            time.sleep(delay)
            continue

        text = "".join(deltas).strip() or "\n".join(fallback_text).strip()
        if text:
            print(text)
            return 0
        if attempt < 3:
            time.sleep(2 ** attempt)

    print("No audit text returned after 3 attempts", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
