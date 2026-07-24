import json, re

# Suite deterministica condivisa: benchmark-openvino-models.py (pipeline GenAI)
# e benchmark-api-models.py (endpoint OpenAI-compatible llama-server/OVMS).
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
    # strict: risposta esatta nel formato richiesto; lenient: contenuto giusto
    # anche se avvolto in fence Markdown o testo extra
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
