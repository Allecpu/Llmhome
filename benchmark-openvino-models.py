import json, re, sys, time
from pathlib import Path
import openvino_genai as genai

ROOT = Path(__file__).parent
# template: chatml-nothink prefilla <think></think> per sopprimere il reasoning di Qwen3.5
MODELS = {
    "qwen35-9b": {"path": ROOT / "models/ov/qwen9b", "template": "chatml-nothink"},
    "gemma3-12b": {"path": ROOT / "models/ov/gemma3-12b", "template": "auto"},
}
CASES = [
    ("math", "Rispondi soltanto con il numero: 37 * 19 =", 24, "regex", r"703"),
    ("instruction", "Scrivi esattamente: cielo, mare, terra. Nessun altro testo.", 24, "regex", r"cielo, mare, terra"),
    ("logic", "Tutti i falchi sono uccelli. Nessun uccello è un mammifero. Un falco può essere un mammifero? Rispondi solo sì o no.", 24, "regex", r"no[.!]?"),
    ("json", "Restituisci solo JSON valido con city Roma e temperature 22. Nessun markdown.", 48, "json", {"city":"Roma","temperature":22}),
    ("extract", "Testo: Ordine A17, cliente Luca Bianchi, totale EUR 83.40. Rispondi solo ID|CLIENTE|TOTALE", 40, "regex", r"A17\|Luca Bianchi\|83[.,]40"),
    ("tool", "Chiama get_weather per Roma. Restituisci solo JSON con name e arguments contenente city.", 64, "json", {"name":"get_weather","arguments":{"city":"Roma"}}),
    ("code", "Scrivi solo una funzione Python is_even(n) corretta, senza spiegazioni e markdown.", 64, "contains", ["def is_even","return"]),
    ("italian", "Spiega in italiano in massimo 60 parole perché fare backup offline. Sii concreto.", 100, "quality", None),
    ("summary", "Riassumi in massimo 35 parole: Il server locale mantiene i dati sul dispositivo, evita costi per richiesta e funziona senza Internet, ma richiede hardware adeguato, aggiornamenti e configurazione sicura.", 70, "quality", None),
    ("planning", "Piano numerato di massimo 5 passi per migrare un server API senza downtime. Includi rollback e verifica.", 140, "quality", None),
]

def build_prompt(template, prompt):
    # auto: la pipeline applica il chat template del modello; chatml-nothink:
    # template manuale con prefill <think></think> per sopprimere il reasoning di Qwen3.5
    if template == "auto":
        return prompt
    if template == "chatml-nothink":
        return f"<|im_start|>user\n{prompt}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    raise ValueError(template)

def normalize(text):
    clean = re.sub(r"^<think>.*?</think>\s*", "", text.strip(), flags=re.S)
    return clean.strip()

def strip_fences(text):
    m = re.search(r"```[a-zA-Z]*\n(.*?)```", text, re.S)
    return (m.group(1) if m else text).strip()

def extract_json(text):
    m = re.search(r"\{.*\}", text, re.S)
    if not m: return None
    try: return json.loads(m.group(0))
    except json.JSONDecodeError: return None

def automatic(kind, expected, text):
    # strict: risposta esatta; lenient: contenuto giusto anche se avvolto in fence/testo
    clean = normalize(text)
    if kind == "regex":
        strict = int(bool(re.fullmatch(expected, clean, re.I)))
        return strict, max(strict, int(bool(re.search(expected, strip_fences(clean), re.I))))
    if kind == "json":
        try: strict = int(json.loads(clean) == expected)
        except json.JSONDecodeError: strict = 0
        return strict, max(strict, int(extract_json(clean) == expected))
    if kind == "contains":
        strict = int(all(x in clean.lower() for x in expected))
        return strict, strict
    return None, None

def make_pipe(path):
    if (path / "openvino_model.xml").exists():
        return genai.LLMPipeline(path, "GPU", PERFORMANCE_HINT="LATENCY")
    return genai.VLMPipeline(path, "GPU", PERFORMANCE_HINT="LATENCY")

def save(data, out_path):
    out_path.write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding="utf-8")

def run(name, spec, data, out_path):
    t = time.perf_counter(); pipe = make_pipe(spec["path"])
    result = {"model":name, "load_seconds":time.perf_counter()-t, "cases":[]}
    data["results"].append(result)
    for case_id, prompt, limit, kind, expected in CASES:
        cfg = genai.GenerationConfig(); cfg.max_new_tokens=limit; cfg.do_sample=False
        if spec["template"] != "auto": cfg.apply_chat_template = False
        try:
            t=time.perf_counter(); out=pipe.generate(build_prompt(spec["template"], prompt), generation_config=cfg); elapsed=time.perf_counter()-t; m=out.perf_metrics
        except RuntimeError as error:
            # CL_OUT_OF_RESOURCES lascia la GPU in stato inconsistente: inutile
            # ricreare la pipeline (crash duro del processo), si interrompe la suite
            result["cases"].append({"id":case_id,"prompt":prompt,"error":str(error)})
            save(data, out_path)
            print(f"{name} {case_id}: ERROR {error}", flush=True)
            return
        strict, lenient = automatic(kind, expected, out.texts[0])
        row={"id":case_id,"prompt":prompt,"response":out.texts[0],"automatic_score":strict,"automatic_score_lenient":lenient,"input_tokens":m.get_num_input_tokens(),"generated_tokens":m.get_num_generated_tokens(),"throughput_tps":m.get_throughput().mean,"ttft_ms":m.get_ttft().mean,"elapsed_seconds":elapsed}
        result["cases"].append(row); save(data, out_path)
        print(f"{name} {case_id}: strict={strict} lenient={lenient} tps={row['throughput_tps']:.2f}", flush=True)

selected = sys.argv[1:] or list(MODELS)
out_path = ROOT/f"OPENVINO_MODEL_COMPARISON_{'_'.join(selected)}.json"
data={"created":time.strftime("%Y-%m-%d %H:%M:%S"),"results":[]}
for model_name in selected: run(model_name,MODELS[model_name],data,out_path)
