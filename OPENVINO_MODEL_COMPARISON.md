# Confronto OpenVINO: Qwen 9B vs Gemma 3 12B

Test eseguito il 16 luglio 2026 su Intel Arc A770 16 GB con OpenVINO/GenAI nightly 2026.4, GPU pura e generazione deterministica. Aggiornato dopo la correzione del template chat (vedi «Correzione metodologica»).

| Modello | Velocità mediana | Strict | Lenient | Esito operativo |
|---|---:|---:|---:|---|
| Qwen 3.5 9B INT4 | ~37 token/s | 5/7 | 6/7 | reasoning soppresso, risposte pulite e dirette |
| Gemma 3 12B INT4 | ~24 token/s | 4/7 | 7/7 | contenuto sempre corretto, ma avvolto in fence Markdown |

Punteggio *strict* = risposta esattamente nel formato richiesto; *lenient* = contenuto corretto anche se avvolto in fence Markdown o testo extra.

## Correzione metodologica

Il primo run dava Qwen a 1/7: era un artefatto del banco di prova, non del modello. La `VLMPipeline` applicava il template chat di Qwen, che apre sempre un blocco `<think>`; il budget di 256 token si esauriva nel reasoning prima della risposta. `/no_think` appeso al prompt non funziona perché il template di Qwen 3.5 supporta solo la variabile `enable_thinking`, non il soft switch.

La soluzione è il prefill `<think>\n\n</think>\n\n` nel turno assistant, con template ChatML costruito manualmente e `apply_chat_template=False`. Per Gemma invece il template automatico della pipeline funziona correttamente. Con questo assetto entrambi i modelli rispondono con gli stessi budget di token (24-140 per caso).

L'export `models/ov/qwen9b-language` non è utilizzabile con `LLMPipeline`: è il solo componente language del VLM e si aspetta `inputs_embeds`, non `input_ids`.

## Risultati qualitativi

Qwen, senza reasoning, produce JSON e tool call in formato esatto senza fence (strict pass) e risponde correttamente a matematica, logica e codice. Fallisce solo `extract` (scrive il template letterale `ID|...` invece dell'ID reale) e `instruction` in strict (aggiunge un punto finale). Risposte in italiano, riassunto e piano sono chiare e pertinenti.

Gemma risponde correttamente a tutto sul piano del contenuto (7/7 lenient), ma racchiude sistematicamente JSON e tool call in blocchi ```` ```json ````; in `extract` antepone l'etichetta `ID|`. Per uso programmatico serve post-processing o constrained decoding; con OVMS il tool calling guidato risolverebbe il problema alla radice.

## Latenza reale

Il throughput grezzo favorisce Qwen (~37 vs ~24 token/s) e ora anche la latenza per risposta: suite completa in 10,2 s contro 16,3 s di Gemma. TTFT mediano quasi identico (76 vs 83 ms).

## Stabilità

Gemma completa l'intera suite da sola in un processo dedicato. Il `CL_OUT_OF_RESOURCES` compare sistematicamente quando nello stesso processo girano più pipeline in sequenza (per esempio Qwen seguito da Gemma) e in quel caso il tentativo di ricreare la pipeline fa crashare il processo. Regola operativa: **un modello per processo**. Come server persistente a lungo termine resta da fare uno stress test dedicato (il run originale falliva dopo 6-9 richieste ripetendo la suite nello stesso processo).

## Conclusione

Con il reasoning soppresso correttamente, **Qwen 3.5 9B è il candidato migliore per Hermes**: più veloce, formato di output esatto senza post-processing e stabile. **Gemma 3 12B è pari o superiore sul contenuto** (7/7 lenient) ma richiede estrazione dai fence Markdown e un processo dedicato per evitare l'esaurimento risorse GPU. Il verdetto precedente («Gemma vince per qualità») derivava dal template chat errato nel banco di prova.
