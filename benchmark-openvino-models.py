import json, re, sys, time
from pathlib import Path
import openvino_genai as genai

ROOT = Path(__file__).parent
MODELS = {"qwen35-9b": ROOT / "models/ov/qwen9b", "gemma3-12b": ROOT / "models/ov/gemma3-12b"}
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

def automatic(kind, expected, text):
    clean = text.strip()
    if kind == "regex": return int(bool(re.fullmatch(expected, clean, re.I)))
    if kind == "json":
        try: return int(json.loads(clean) == expected)
        except json.JSONDecodeError: return 0
    if kind == "contains": return int(all(x in clean.lower() for x in expected))
    return None

def run(name, path):
    t = time.perf_counter(); pipe = genai.VLMPipeline(path, "GPU", PERFORMANCE_HINT="LATENCY")
    result = {"model":name, "load_seconds":time.perf_counter()-t, "cases":[]}
    for case_id, prompt, limit, kind, expected in CASES:
        if name == "qwen35-9b": prompt += " /no_think"
        if name == "qwen35-9b": limit = max(limit, 256)
        cfg = genai.GenerationConfig(); cfg.max_new_tokens=limit; cfg.do_sample=False
        try:
            t=time.perf_counter(); out=pipe.generate(prompt, generation_config=cfg); elapsed=time.perf_counter()-t; m=out.perf_metrics
        except RuntimeError as error:
            result["cases"].append({"id":case_id,"prompt":prompt,"error":str(error)})
            print(f"{name} {case_id}: ERROR {error}", flush=True)
            break
        row={"id":case_id,"prompt":prompt,"response":out.texts[0],"automatic_score":automatic(kind,expected,out.texts[0]),"input_tokens":m.get_num_input_tokens(),"generated_tokens":m.get_num_generated_tokens(),"throughput_tps":m.get_throughput().mean,"ttft_ms":m.get_ttft().mean,"elapsed_seconds":elapsed}
        result["cases"].append(row); print(f"{name} {case_id}: score={row['automatic_score']} tps={row['throughput_tps']:.2f}", flush=True)
    return result

selected = sys.argv[1:] or list(MODELS)
data={"created":time.strftime("%Y-%m-%d %H:%M:%S"),"results":[]}
for model_name in selected: data["results"].append(run(model_name,MODELS[model_name]))
(ROOT/f"OPENVINO_MODEL_COMPARISON_{'_'.join(selected)}.json").write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding="utf-8")
