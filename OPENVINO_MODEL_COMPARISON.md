# Confronto OpenVINO: Qwen 9B vs Gemma 3 12B

Test eseguito il 16 luglio 2026 su Intel Arc A770 16 GB con OpenVINO/GenAI nightly 2026.4, GPU pura e generazione deterministica.

| Modello | Velocità tipica | Test automatici stretti | Esito operativo |
|---|---:|---:|---|
| Qwen 3.5 9B INT4 | ~39 token/s | 1/7 | reasoning visibile, output spesso troncato |
| Gemma 3 12B INT4 | ~24 token/s | 4/7 | risposte corrette e concise, ma formattazione non sempre stretta |

## Risultati qualitativi

Gemma ha risposto correttamente a matematica, logica e istruzioni esatte. JSON e tool call contenevano i dati corretti, ma erano racchiusi in blocchi Markdown; l'estrazione ha aggiunto l'etichetta `ID`. Le risposte italiane e il riassunto erano chiari e pertinenti. Il piano era troppo verboso rispetto al limite.

Qwen ha individuato internamente le risposte corrette, ma ha emesso sempre `Thinking Process`. Né `/no_think` né `enable_thinking=False` passati alla pipeline hanno disattivato il comportamento. Anche con 256 token molte risposte non hanno raggiunto l'output finale, rendendo inaffidabili JSON, tool calling e istruzioni a formato rigido.

## Stabilità

Qwen ha completato dieci richieste consecutive. Gemma ha completato la prima suite, ma nelle ripetizioni successive è andato in `CL_OUT_OF_RESOURCES` dopo 6-9 richieste; `KV_CACHE_PRECISION=u4` non ha risolto. Il comportamento indica un problema di memoria o frammentazione del plugin GPU da approfondire prima dell'uso come server persistente.

## Conclusione

**Gemma 3 12B è il miglior modello per qualità delle risposte tra i due candidati**, mentre **Qwen 9B resta il runtime più veloce e stabile**. Nessuno dei due è ancora pronto come vincitore assoluto per Hermes: Gemma deve superare uno stress test persistente; Qwen richiede una configurazione affidabile che sopprima o separi il reasoning.
