import json, sys, time
from pathlib import Path
import openvino_genai as genai
from benchmark_cases import CASES, automatic

ROOT = Path(__file__).parent
# template: chatml-nothink prefilla <think></think> per sopprimere il reasoning di Qwen3.5
MODELS = {
    "qwen35-9b": {"path": ROOT / "models/ov/qwen9b", "template": "chatml-nothink"},
}
def build_prompt(template, prompt):
    # auto: la pipeline applica il chat template del modello; chatml-nothink:
    # template manuale con prefill <think></think> per sopprimere il reasoning di Qwen3.5
    if template == "auto":
        return prompt
    if template == "chatml-nothink":
        return f"<|im_start|>user\n{prompt}<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n"
    raise ValueError(template)

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
