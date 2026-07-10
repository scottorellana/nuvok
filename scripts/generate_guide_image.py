#!/usr/bin/env python3
"""Generate an image via Codex OAuth gpt-image-2 (no API key needed)."""
import httpx, json, base64, sys, os, mimetypes

HERMES_HOME = os.environ.get("HERMES_HOME", os.path.expanduser("~/.hermes"))
auth = json.loads(open(f"{HERMES_HOME}/auth.json").read())
token = auth["credential_pool"]["openai-codex"][0]["access_token"]

PROMPT = sys.argv[1]
OUT_PATH = sys.argv[2]
SIZE = sys.argv[3] if len(sys.argv) > 3 else "1536x1024"
QUALITY = sys.argv[4] if len(sys.argv) > 4 else "high"
REFERENCE = sys.argv[5] if len(sys.argv) > 5 else None

content = [{"type": "input_text", "text": PROMPT}]
if REFERENCE:
    mime = mimetypes.guess_type(REFERENCE)[0] or "image/png"
    encoded = base64.b64encode(open(REFERENCE, "rb").read()).decode("ascii")
    content.append({
        "type": "input_image",
        "image_url": f"data:{mime};base64,{encoded}",
    })

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
    "instructions": "You are an image generation assistant. Generate the requested image exactly as described. Do not add text, watermarks, or labels to the image.",
    "input": [{
        "type": "message",
        "role": "user",
        "content": content,
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

            def find_b64(obj, depth=0):
                if depth > 10:
                    return None
                if isinstance(obj, str) and len(obj) > 1000:
                    return obj
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        if k in ("result", "b64", "image") and isinstance(v, str) and len(v) > 1000:
                            return v
                        found = find_b64(v, depth + 1)
                        if found:
                            return found
                if isinstance(obj, list):
                    for item in obj:
                        found = find_b64(item, depth + 1)
                        if found:
                            return found
                return None

            found = find_b64(event)
            if found:
                last_image = base64.b64decode(found)
                last_event_type = event.get("type", "unknown")
                print(
                    f"received {last_event_type} ({len(last_image):,} bytes); waiting for final stream event",
                    file=sys.stderr,
                )

if last_image:
    os.makedirs(os.path.dirname(OUT_PATH) or ".", exist_ok=True)
    with open(OUT_PATH, "wb") as f:
        f.write(last_image)
    print(f"OK {OUT_PATH} ({len(last_image):,} bytes, last event: {last_event_type})")
    sys.exit(0)

print("No image found in stream", file=sys.stderr)
sys.exit(1)
