#!/usr/bin/env python3
"""Generate Nuvok logo proposals via Codex OAuth gpt-image-2."""
import httpx, json, base64, sys, os

HERMES_HOME = os.environ.get("HERMES_HOME", os.path.expanduser("~/.hermes"))
auth = json.loads(open(f"{HERMES_HOME}/auth.json").read())
token = auth["credential_pool"]["openai-codex"][0]["access_token"]

PROMPT = sys.argv[1]
OUT_PATH = sys.argv[2]
SIZE = sys.argv[3] if len(sys.argv) > 3 else "1024x1024"
QUALITY = sys.argv[4] if len(sys.argv) > 4 else "high"

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
    "instructions": "You are an expert brand designer. Generate the requested logo/icon exactly as described. Do not add text, watermarks, or labels.",
    "input": [{
        "type": "message",
        "role": "user",
        "content": [{"type": "input_text", "text": PROMPT}],
    }],
    "tools": [{
        "type": "image_generation",
        "model": "gpt-image-2",
        "size": SIZE,
        "quality": QUALITY,
        "output_format": "png",
        "background": "opaque",
        "partial_images": 1,
    }],
    "tool_choice": {
        "type": "allowed_tools",
        "mode": "required",
        "tools": [{"type": "image_generation"}],
    },
    "stream": True,
}

def find_b64(obj, depth=0):
    if depth > 10:
        return None
    if isinstance(obj, str) and len(obj) > 1000:
        return obj
    if isinstance(obj, dict):
        for key, value in obj.items():
            if key in ("result", "b64", "image") and isinstance(value, str) and len(value) > 1000:
                return value
            found = find_b64(value, depth + 1)
            if found:
                return found
    if isinstance(obj, list):
        for item in obj:
            found = find_b64(item, depth + 1)
            if found:
                return found
    return None

last_image = None
last_event_type = None
with httpx.Client(timeout=httpx.Timeout(300.0), headers=headers) as http:
    with http.stream("POST", "https://chatgpt.com/backend-api/codex/responses",
                     json=payload) as response:
        response.raise_for_status()
        for line in response.iter_lines():
            if not line or not line.startswith("data: "):
                continue
            data_str = line[6:]
            if data_str == "[DONE]":
                break
            event = json.loads(data_str)
            found = find_b64(event)
            if found:
                last_image = base64.b64decode(found)
                last_event_type = event.get("type", "unknown")

if not last_image:
    print("No image found in stream", file=sys.stderr)
    sys.exit(1)

os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
with open(OUT_PATH, "wb") as image_file:
    image_file.write(last_image)
print(f"OK {OUT_PATH} ({len(last_image):,} bytes) final_event={last_event_type}")
