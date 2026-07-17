import json, sys, time, urllib.request
from pathlib import Path
from benchmark_cases import CASES, automatic

# Suite qualità contro un endpoint OpenAI-compatible (llama-server, OVMS).
# Uso: python benchmark-api-models.py <label> [base_url] [api_key_file] [--nothink]
# Default: http://127.0.0.1:8080/v1 con chiave da llama-api-key.txt.
# <label> è anche il campo "model" della richiesta (OVMS lo richiede).
# --nothink: disattiva il reasoning via chat_template_kwargs (Qwen su OVMS).

ROOT = Path(__file__).parent
args = [a for a in sys.argv[1:] if a != "--nothink"]
nothink = "--nothink" in sys.argv
label = args[0]
base = (args[1] if len(args) > 1 else "http://127.0.0.1:8080/v1").rstrip("/")
key_file = ROOT / (args[2] if len(args) > 2 else "llama-api-key.txt")
api_key = key_file.read_text(encoding="utf-8").strip() if key_file.exists() else ""

def chat(prompt, max_tokens):
    body = json.dumps({
        "model": label,
        "messages": [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "temperature": 0,
        **({"chat_template_kwargs": {"enable_thinking": False}} if nothink else {}),
    }).encode("utf-8")
    req = urllib.request.Request(f"{base}/chat/completions", data=body,
        headers={"Content-Type": "application/json",
                 **({"Authorization": f"Bearer {api_key}"} if api_key else {})})
    with urllib.request.urlopen(req, timeout=300) as resp:
        return json.load(resp)

data = {"created": time.strftime("%Y-%m-%d %H:%M:%S"), "endpoint": base,
        "results": [{"model": label, "cases": []}]}
result = data["results"][0]
out_path = ROOT / f"API_MODEL_COMPARISON_{label}.json"

for case_id, prompt, limit, kind, expected in CASES:
    t = time.perf_counter()
    try:
        reply = chat(prompt, limit)
    except Exception as error:
        result["cases"].append({"id": case_id, "prompt": prompt, "error": str(error)})
        print(f"{label} {case_id}: ERROR {error}", flush=True)
        continue
    elapsed = time.perf_counter() - t
    text = reply["choices"][0]["message"].get("content") or ""
    usage = reply.get("usage", {})
    strict, lenient = automatic(kind, expected, text)
    row = {"id": case_id, "prompt": prompt, "response": text,
           "automatic_score": strict, "automatic_score_lenient": lenient,
           "completion_tokens": usage.get("completion_tokens"),
           "elapsed_seconds": elapsed}
    result["cases"].append(row)
    out_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"{label} {case_id}: strict={strict} lenient={lenient} {elapsed:.1f}s", flush=True)

out_path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
scored = [c for c in result["cases"] if c.get("automatic_score") is not None]
print(f"{label}: strict {sum(c['automatic_score'] for c in scored)}/{len(scored)}",
      f"lenient {sum(c['automatic_score_lenient'] for c in scored)}/{len(scored)}")
