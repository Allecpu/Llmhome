# Benchmark modelli locali con LM Studio

Data del test: 14 luglio 2026  
Sistema operativo: Windows  
Runtime: LM Studio CLI (`lms`)

## Obiettivo

Individuare il modello locale più adatto alla macchina, confrontando qualità della risposta, velocità, tempo al primo token, utilizzo della memoria e praticità d'uso. Al termine sono stati eliminati i modelli non selezionati.

## Hardware rilevato

| Componente | Specifica |
|---|---|
| CPU | Intel Core i5-13600K |
| Core / thread | 14 / 20 |
| RAM | 47,7 GB (48 GB installati) |
| GPU | Intel Arc A770 |
| VRAM | 16 GB, confermati dall'utente |

Nota: Windows CIM riportava erroneamente 2 GB di VRAM a causa del limite/errore del campo `AdapterRAM`. Il valore reale è 16 GB.

## Installazione LM Studio iniziale

La CLI è stata trovata in:

```text
C:\Users\allec\.lmstudio\bin\lms.exe
```

Modelli inizialmente installati:

- `google/gemma-4-e4b`, 6,33 GB
- `qwen/qwen3.5-9b`, 6,55 GB
- `text-embedding-nomic-embed-text-v1.5`, 84,11 MB

## Metodo di prova

I modelli sono stati caricati principalmente con:

- contesto: 8.192 token;
- parallelismo: 1 nei test dei modelli più grandi;
- offload GPU massimo o automatico;
- stesso problema logico delle tre scatole;
- generazione di una funzione Python `is_prime(n)` corretta anche per `n < 2`;
- statistiche prodotte da `lms chat --stats`.

Il prompt verificava contemporaneamente:

1. comprensione dell'italiano;
2. ragionamento logico;
3. completezza della spiegazione;
4. capacità di scrivere codice Python corretto ed efficiente.

## Risultati

### Qwen 3.5 9B

Configurazione:

- dimensione su disco: 6,55 GB;
- memoria caricata: 6,10 GiB;
- contesto: 8K;
- offload GPU completo.

Risultati:

| Metrica | Valore |
|---|---:|
| Caricamento | 12,75 s |
| Tempo al primo token | 5,630 s |
| Generazione | 40,88 token/s |
| Token generati | 2.433 |

Valutazione: risposta completa e codice efficiente, ma reasoning interno molto lungo e visibile nella CLI.

### Gemma 4 E4B

Configurazione:

- dimensione su disco: 6,33 GB;
- memoria caricata: 5,89 GiB;
- contesto: 8K;
- offload GPU completo.

Risultati:

| Metrica | Valore |
|---|---:|
| Caricamento | 9,15 s |
| Tempo al primo token | 3,197 s |
| Generazione | 49,72 token/s |
| Token generati | 1.438 |

Valutazione: modello più veloce del primo gruppo, ma risposta meno completa di Qwen 3.5 9B.

### Gemma 4 12B

È stata scaricata automaticamente da LM Studio la variante:

```text
Gemma 4 12B Instruct Q4_K_M GGUF
```

Configurazione:

- download: 7,56 GB;
- memoria caricata: 7,04 GiB;
- contesto: 8K;
- parallelismo: 1;
- offload GPU completo.

Risultati:

| Metrica | Valore |
|---|---:|
| Caricamento | 6,37 s |
| Tempo al primo token | 1,637 s |
| Generazione | 27,44 token/s |
| Token generati | 797 |

Valutazione: primo token rapido, ma generazione più lenta e risposta logica meno completa e più confusa rispetto a Qwen 3.5 9B.

### Gemma 4 26B-A4B

È stata scaricata la variante GGUF Q4 proposta da LM Studio.

Configurazione:

- dimensione su disco: 17,99 GB;
- memoria caricata: 16,76 GiB;
- contesto: 8K;
- parallelismo: 1;
- offload automatico GPU/RAM;
- architettura Mixture-of-Experts, circa 4B parametri attivi per token.

Risultati:

| Metrica | Valore |
|---|---:|
| Caricamento | 10,98 s |
| Tempo al primo token | 7,473 s |
| Generazione | 26,19 token/s |
| Token generati | 1.135 |

Valutazione: risposta completa in entrambi i casi del problema logico e implementazione di `is_prime` più efficiente, basata sul controllo dei divisori nella forma `6k ± 1`. Nonostante il leggero offload in RAM, la velocità è rimasta pratica.

### Qwen 3.6 27B

Configurazione:

- variante GGUF Q4;
- dimensione: 17,48 GB;
- contesto: 8K;
- parallelismo: 1;
- offload automatico;
- architettura densa da 27B parametri.

Esito: il modello risultava ancora nello stato `GENERATING` dopo oltre tre minuti e il comando ha raggiunto il timeout. Il tentativo di usare `/no_think` non ha disabilitato il reasoning nella configurazione CLI utilizzata.

Questo non significa che il modello non funzioni. Con queste impostazioni non ha terminato entro il limite perché:

- il thinking era ancora attivo;
- il modello superava i 16 GB di VRAM e usava anche la RAM;
- essendo denso, ogni token coinvolge molti più pesi rispetto a un MoE A4B;
- l'output non aveva un limite massimo esplicito di token;
- il backend Intel Arc può essere meno ottimizzato per questa architettura.

### GLM-4.7 Flash 30B-A3B

Configurazione:

- variante GGUF Q4;
- dimensione: 18,13 GB;
- contesto: 8K;
- parallelismo: 1;
- offload automatico;
- architettura MoE, circa 3B parametri attivi.

Esito: anche GLM risultava ancora nello stato `GENERATING` dopo oltre tre minuti. Il test è stato interrotto al timeout.

Anche in questo caso non si tratta di un errore di caricamento: il modello era caricato e stava generando, ma non ha completato la risposta entro il limite con reasoning attivo, offload in RAM e output non limitato.

## Confronto sintetico

| Modello | Dimensione | Token/s | Primo token | Esito pratico |
|---|---:|---:|---:|---|
| Gemma 4 E4B | 6,33 GB | 49,72 | 3,197 s | Molto veloce, qualità inferiore |
| Qwen 3.5 9B | 6,55 GB | 40,88 | 5,630 s | Buon equilibrio nella fascia piccola |
| Gemma 4 12B | 7,56 GB | 27,44 | 1,637 s | Non abbastanza migliore dei modelli piccoli |
| Gemma 4 26B-A4B | 17,99 GB | 26,19 | 7,473 s | Miglior qualità pratica testata |
| Qwen 3.6 27B | 17,48 GB | N/D | N/D | Non concluso entro 3 minuti |
| GLM-4.7 Flash | 18,13 GB | N/D | N/D | Non concluso entro 3 minuti |

## Modello selezionato

Il vincitore dei test è:

```text
google/gemma-4-26b-a4b
```

Motivi:

- migliore qualità osservata nei test completati;
- risposta logica completa;
- codice Python corretto ed efficiente;
- circa 26 token/s, velocità adeguata per uso interattivo;
- architettura MoE adatta ai 16 GB di VRAM della Arc A770;
- piccolo offload in RAM sostenibile grazie ai 48 GB installati.

## Pulizia effettuata

Sono stati eliminati definitivamente:

- Gemma 4 E4B;
- Gemma 4 12B;
- Qwen 3.5 9B;
- Qwen 3.6 27B;
- GLM-4.7 Flash 30B-A3B.

La rimozione è stata effettuata verificando preventivamente che ogni percorso fosse contenuto in:

```text
C:\Users\allec\.lmstudio\models\lmstudio-community
```

## Configurazione finale

Modelli rimasti in LM Studio:

| Modello | Funzione | Dimensione |
|---|---|---:|
| `google/gemma-4-26b-a4b` | Chat, ragionamento, coding e multimodale | 17,99 GB |
| `text-embedding-nomic-embed-text-v1.5` | Embedding per ricerca e RAG | 84,11 MB |

Spazio totale occupato: circa 18,08 GB.

Al termine dei test tutti i modelli sono stati scaricati dalla memoria; la VRAM è quindi libera.

## Limiti del benchmark

Il verdetto riguarda le varianti e le impostazioni effettivamente provate. Qwen 3.6 e GLM potrebbero essere rivalutati con:

- thinking disabilitato tramite il controllo specifico di LM Studio;
- limite di 300-500 token in output;
- contesto ridotto a 4K;
- quantizzazione Q3 che entri interamente nei 16 GB di VRAM;
- runtime Intel/LM Studio aggiornato e meglio ottimizzato.

Pertanto Gemma 4 26B-A4B è il miglior modello **pratico fra quelli testati con la configurazione descritta**, non una garanzia assoluta rispetto a ogni modello o quantizzazione possibile.

## Confronto server Vulkan e SYCL

È stato successivamente confrontato `llama.cpp` build ufficiale `b10002` usando lo stesso file Gemma 4 26B-A4B Q4_K_M e gli stessi parametri:

- 512 token di prompt;
- 128 token generati;
- 3 ripetizioni;
- 99 layer GPU;
- Flash Attention attiva;
- `mmap` disattivato;
- batch 2.048 e micro-batch 512.

La Arc A770 è stata riconosciuta correttamente da SYCL sia via Level Zero sia via OpenCL.

| Backend | Prompt processing | Generazione |
|---|---:|---:|
| SYCL / Level Zero | 429,82 token/s | 18,82 token/s |
| Vulkan | 227,42 token/s | 36,89 token/s |

Conclusioni:

- SYCL è circa l'89% più rapido nell'elaborazione iniziale di prompt lunghi;
- Vulkan è circa il 96% più rapido nella generazione dei token;
- per chat e server interattivo sulla A770, Vulkan è il backend preferibile;
- SYCL può essere interessante per carichi con prompt molto lunghi e output brevi;
- LM Studio usa già Vulkan, ma la sua runtime installata era meno recente della build standalone provata;
- il binario standalone aggiornato `llama-server` Vulkan può offrire più controllo e potenzialmente prestazioni superiori, senza cambiare formato del modello.

Il server standalone conservato si trova in:

```text
C:\Github\Llm\tools\llama-vulkan-b10002\llama-server.exe
```

È stato creato anche lo script pronto all'uso:

```text
C:\Github\Llm\start-gemma-server.ps1
```

Lo script avvia un endpoint OpenAI-compatible su `http://127.0.0.1:8080`, con contesto 64K, Flash Attention, un solo slot, prompt cache, metriche e reasoning disabilitato. Con Qwen 3.5 9B la KV cache usa Q8; l'opzione `--fit on` regola automaticamente l'offload GPU/RAM con un margine target di 256 MiB. Le risposte sono limitate a un massimo di 2.048 token per evitare che una generazione senza termine occupi indefinitamente l'unico slot.

In seguito alle prestazioni insufficienti di Gemma 4 26B-A4B con il contesto minimo 64K richiesto da Hermes, il launcher è stato riconfigurato su `Qwen3.5-9B-Q4_K_M.gguf`. Il modello da 5,24 GiB lascia spazio sufficiente in VRAM per contesto 64K, cache KV Q8 e buffer Vulkan, evitando l'offload pesante in RAM. Gemma 4 26B-A4B rimane installato per utilizzi a contesto ridotto e massima qualità.

La configurazione Qwen 3.5 9B è stata verificata con una richiesta locale OpenAI-compatible: server pronto correttamente e risposta `OK` completata in 1,16 secondi, con 18 token di prompt e 2 token generati.

Per il carico ripetitivo di Hermes sono state aggiunte ulteriori ottimizzazioni al server:

- memory mapping Vulkan attivo per ridurre tempi e duplicazioni nel caricamento;
- prompt cache attiva;
- riuso della KV cache per blocchi di almeno 256 token (`--cache-reuse 256`);
- 14 thread CPU sia per generazione sia per batch;
- batch logico 2.048 e micro-batch 512;
- un solo slot, perché Hermes richiede almeno 64K per ciascuno e più slot dividerebbero il contesto o aumenterebbero fortemente l'uso di memoria.

La documentazione Hermes conferma che il prompt viene organizzato in livelli stabili, contestuali e volatili per favorire il caching. Il comando `hermes prompt-size --json`, eseguito sulla macchina client, permette di individuare skill, memoria o profilo che aumentano maggiormente il prompt fisso.

### Avvio tramite file BAT

Per facilitare l'avvio da Windows è stato creato anche:

```text
C:\Github\Llm\start-gemma-server.bat
```

Il file può essere eseguito con un doppio clic oppure da terminale:

```bat
start-gemma-server.bat
```

Il launcher:

- si posiziona automaticamente nella cartella `C:\Github\Llm`;
- richiama `start-gemma-server.ps1` con una policy PowerShell temporaneamente permissiva;
- mostra nella console l'indirizzo del server;
- lascia visibili log ed eventuali errori;
- non richiede di modificare permanentemente la Execution Policy di Windows.

Endpoint OpenAI-compatible:

```text
http://127.0.0.1:8080/v1
```

Per arrestare il server è sufficiente premere `Ctrl+C` nella finestra del launcher.

### Accesso dalla rete locale

Il server è stato successivamente configurato per ascoltare su tutte le interfacce locali:

```text
--host 0.0.0.0
```

Indirizzo rilevato sulla rete Ethernet:

```text
http://192.168.1.22:8080/v1
```

È stata creata la regola Windows Firewall `Llama Server LAN 8080` con le seguenti restrizioni:

- porta TCP 8080;
- solo traffico in ingresso;
- solo profilo di rete Privato;
- solo dispositivi appartenenti alla sottorete locale (`LocalSubnet`);
- nessuna apertura o inoltro sul router Internet.

Il server richiede autenticazione. La chiave è conservata localmente in:

```text
C:\Github\Llm\llama-api-key.txt
```

Il file è incluso in `.gitignore` per evitare che la chiave venga aggiunta accidentalmente a Git. I client devono inviarla nell'header HTTP:

```text
Authorization: Bearer <contenuto-di-llama-api-key.txt>
```

Esempio di configurazione per un client OpenAI-compatible:

```text
Base URL: http://192.168.1.22:8080/v1
API key: contenuto del file llama-api-key.txt
```

L'indirizzo IP potrebbe cambiare se il router assegna un nuovo lease DHCP; in tal caso è consigliabile configurare una prenotazione DHCP per `192.168.1.22`.

## Verifica Qwen 3.6 35B-A3B a 64K

Il 15 luglio 2026 è stato provato `Qwen 3.6 35B-A3B IQ3_XXS` (MoE, circa 15,76 GB su disco). Questa quantizzazione molto aggressiva era l'unica variante 35B con margine plausibile sulla Arc A770 da 16 GB insieme alla cache da 64K.

Benchmark comparabile con `llama-bench` b10002 Vulkan, Flash Attention, KV Q4, prompt 512 token, generazione 128 token e tre ripetizioni:

| Modello | Prompt processing | Generazione |
|---|---:|---:|
| Qwen 3.5 9B Q4_K_M | 657,93 token/s | 40,80 token/s |
| Qwen 3.6 35B-A3B IQ3_XXS | 144,03 token/s | 44,05 token/s |

Il benchmark sintetico mostrava una generazione leggermente più veloce per il 35B MoE, ma un'elaborazione del prompt circa 4,6 volte più lenta. La prova decisiva è stata quindi eseguita tramite server OpenAI-compatible con contesto reale 65.536, un solo slot, reasoning disabilitato e cache KV Q4.

Sulla stessa richiesta Python, con 31 token di prompt e 109 token di risposta:

| Modello | Tempo totale | Esito |
|---|---:|---|
| Qwen 3.6 35B-A3B IQ3_XXS | 114,21 s | risposta corretta |
| Qwen 3.5 9B Q4_K_M | 2,89 s | risposta corretta |

Il 9B è risultato circa 39,5 volte più rapido nel caso reale. Nei log del 35B la generazione, una volta avviata, raggiungeva circa 28-30 token/s; il tempo veniva però dominato dal prompt processing a 64K, sceso fino a 0,27 token/s in una richiesta. Questo rende il modello inadatto a Hermes sulla configurazione corrente, anche se il benchmark di generazione isolata appare favorevole.

È stato inoltre rilevato che specificare contemporaneamente `--gpu-layers all` e `--fit on` impedisce a `llama-server` di applicare il fit automatico. Il parametro `--gpu-layers all` è stato quindi rimosso dal launcher: `--fit on --fit-target 256` può ora scegliere automaticamente l'offload mantenendo il margine VRAM richiesto.

Conclusione aggiornata: `Qwen 3.5 9B Q4_K_M` resta il miglior modello verificato su questa macchina per Hermes con contesto 64K, considerando insieme qualità, latenza e stabilità. Il 35B IQ3_XXS e il relativo download MTP accidentale sono stati eliminati, recuperando circa 17,85 GB. Il server LAN è stato ripristinato sul 9B ed è stato verificato tramite API.

## Confronto OpenVINO nativo e OVMS Docker

Il 15 luglio 2026 è stato verificato anche OpenVINO come alternativa Intel nativa. È stato usato il modello ufficiale `OpenVINO/Qwen3.5-9B-int4-ov` da circa 5,71 GiB e OpenVINO GenAI nightly `2026.4.0.dev20260713`. Il runtime Windows ha rilevato esplicitamente sia la CPU sia `Intel Arc A770 Graphics (dGPU)`.

Risultati OpenVINO GenAI nativo sulla GPU:

| Prova | Risultato |
|---|---:|
| Caricamento e compilazione modello | circa 8,6 s |
| Generazione isolata | circa 36 token/s |
| Prompt API da 8.205 token | 2,76 s, circa 2.970 token/s |
| Prompt diretto da 60.002 token | 31,16 s, circa 1.925 token/s |

Il test da 60K ha confermato che OpenVINO può gestire il requisito di contesto 64K sulla A770. Nel prefill è risultato molto più rapido di llama.cpp Vulkan, il cui benchmark comparabile sul Qwen 9B aveva raggiunto circa 658 token/s. La generazione OpenVINO è invece leggermente più lenta dei circa 40,8 token/s di Vulkan.

È stato creato e provato anche un server OpenAI-compatible nativo Windows con FastAPI, autenticazione e template ufficiale Qwen. La stessa richiesta Python ha impiegato 3,62 s per 31 token di prompt e 128 token generati. Nonostante il template terminasse correttamente il blocco `<think></think>` e `reasoning_effort` fosse impostato a `none`, la conversione OpenVINO ufficiale continuava a produrre in chiaro il proprio processo di ragionamento, consumando tutta la risposta breve senza arrivare al codice. Il server sperimentale, inoltre, non implementava ancora streaming SSE e conversione completa delle chiamate tool XML nel formato OpenAI.

È stato poi provato OpenVINO Model Server `2026.0-gpu` e `2026.2-gpu` in Docker Desktop/WSL2. Il passthrough ufficiale con `/dev/dxg`, mount di `/usr/lib/wsl` e `LD_LIBRARY_PATH=/usr/lib/wsl/lib` ha funzionato: OVMS riportava dispositivi disponibili `CPU, GPU`. La preparazione del repository ha però incontrato due problemi operativi:

- su bind mount NTFS, Git LFS non riusciva a impostare i permessi Unix e duplicava i pesi nella cartella `.git`, portando la copia a circa 11,4 GiB;
- dopo il passaggio a un volume Linux con permessi corretti, Docker Desktop si è arrestato durante il trasferimento LFS con `unexpected EOF`.

Verdetto complessivo:

- OpenVINO è il motore migliore tra quelli provati per elaborare prompt molto lunghi sulla Arc A770;
- llama.cpp Vulkan resta leggermente migliore nella velocità di generazione;
- per Hermes, oggi llama.cpp resta la scelta più efficiente nel complesso grazie a reasoning disabilitato correttamente, streaming, tool calling, API stabile e semplicità operativa;
- OVMS potrebbe diventare la scelta migliore quando parser/template Qwen 3.5 e deploy Windows saranno sufficientemente stabili, perché il vantaggio di prefill è molto grande.

Al termine della prova sono stati eliminati modello OpenVINO, repository duplicato, volume Docker, immagini OVMS e ambiente Python temporaneo. Docker Desktop è stato arrestato e il server LAN `llama-server` è stato ripristinato sul Qwen 3.5 9B all'indirizzo `http://192.168.1.22:8080/v1`.

## Sweep di prefill a profondità crescenti (16 luglio 2026)

Per quantificare il vero collo di bottiglia di Hermes — il *prompt processing* a contesto quasi pieno, non la sola generazione — è stato aggiunto lo script `bench-prefill.ps1`. Usa `llama-bench` (Vulkan b10002, Flash Attention attiva, cache KV Q8) ed esegue ogni test come invocazione separata per evitare il prodotto cartesiano di `llama-bench`. Misura il prefill di un blocco da 512 token a profondità 0 / 8K / 32K / 64K, il prefill a freddo dell'intero contesto 64K e la generazione con KV già pieno a 64K.

Driver Arc rilevato: `32.0.101.8861` (ben oltre la soglia `31.0.101.5522` sotto cui il backend Vulkan produce output corrotto).

| Test | Qwen 3.5 9B (5,23 GiB) | Gemma 4 26B-A4B (15,63 GiB) |
|---|---:|---:|
| prefill 512 @ profondità 0 | 684,3 token/s | 262,4 token/s |
| prefill 512 @ profondità 8K | 488,8 token/s | 119,5 token/s |
| prefill 512 @ profondità 64K | 163,2 token/s | 37,5 token/s |
| prefill 64K a freddo (media) | 262,1 token/s (~250 s) | 62,7 token/s (~17 min) |
| generazione @ profondità 64K | 26,3 token/s | 11,7 token/s |

Interpretazione:

- il prefill degrada con la profondità per entrambi i modelli (costo dell'attention sul KV crescente), ma il 9B resta 2,6–4,4 volte più rapido a ogni profondità;
- Gemma 26B-A4B pesa 15,63 GiB e con la cache KV 64K supera i 16 GB di VRAM: l'offload/spill in RAM (banda ~80 GB/s DDR5 contro ~560 GB/s VRAM Arc, circa 7 volte più lenta) domina tutti i tempi;
- il prefill 64K a freddo di Gemma richiede circa 17 minuti, inutilizzabile per Hermes; il 9B lo completa in circa 4 minuti e, grazie al prompt-caching a livelli di Hermes, lo paga di rado;
- il muro è di **capacità di VRAM**, non di calcolo. SYCL o l'XMX Flash Attention accelerano solo la parte compute-bound dell'attention, non la banda RAM del modello spillato: non possono recuperare un modello che non entra in VRAM insieme al KV 64K.

Conclusione operativa: su Arc A770 da 16 GB con contesto 64K, l'unico percorso verso un modello migliore del 9B è un modello che **entri interamente** in VRAM lasciando spazio al KV. Gemma 26B-A4B e le taglie 27B/35B sono escluse per capacità. Il candidato residuo da verificare è `GPT-OSS 20B` (MXFP4 nativo ~11,5 GiB, MoE con ~3,6B parametri attivi, function-calling nativo): entra in VRAM, ma su Arc + Vulkan produce attualmente output corrotto (issue llama.cpp #17013, #17643). Va provato con un backend/build che lo renda correttamente (SYCL, già funzionante sulla A770, o una build Vulkan aggiornata).

## Verifica GPT-OSS 20B su build Vulkan b10038 (16 luglio 2026)

È stata scaricata la build `llama.cpp` `b10038` (36 build più recente della `b10002` in uso) ed estratta in `tools/llama-vulkan-b10038/`, insieme al modello ufficiale `ggml-org/gpt-oss-20b-GGUF` (`gpt-oss-20b-mxfp4.gguf`, 12,1 GB su disco, 11,27 GiB caricato). Script aggiunti: `bench-prefill.ps1` esteso (`-Model gptoss -Build b10038`) e `smoke-gptoss.ps1`.

**Correttezza:** su `b10038` il bug gibberish di Arc + Vulkan è risolto. Lo smoke test (`llama-cli --jinja -st`, prompt `17 * 23`) ha prodotto output coerente e corretto (`17 multiplied by 23 is 391.`) a circa 54 token/s di generazione a basso contesto. Il modello entra interamente in VRAM (11,27 GiB, nessun offload).

**Prefill/generazione (llama-bench, Vulkan b10038, FA on, KV Q8):**

| Test | GPT-OSS 20B | Qwen 3.5 9B | Vincitore |
|---|---:|---:|---|
| prefill 512 @ profondità 0 | 942,2 token/s | 684,3 token/s | GPT-OSS +38% |
| prefill 512 @ profondità 8K | 668,4 token/s | 488,8 token/s | GPT-OSS +37% |
| prefill 512 @ profondità 32K | 268,1 token/s | 262,3 token/s | pari |
| prefill 512 @ profondità 64K | 156,7 token/s | 163,2 token/s | pari |
| prefill 64K a freddo (media) | 256,2 token/s | 262,1 token/s | pari |
| generazione @ profondità 64K | 18,4 token/s | 26,3 token/s | Qwen +43% |

**Tool-calling:** server OpenAI-compatible (`--jinja --reasoning off`), richiesta con array `tools` e `tool_choice:auto`. Risposta corretta: `finish_reason: tool_calls`, funzione `get_weather`, argomenti `{"city":"Roma"}`, formato OpenAI valido. Il ragionamento resta separato nel campo `reasoning_content` con `content` vuoto: pulito per Hermes, che legge `content`/`tool_calls`.

**Verdetto:** GPT-OSS 20B è pienamente utilizzabile su questa macchina con la build `b10038` (entra in VRAM, rende correttamente, tool-calling OpenAI valido). Sul solo aspetto **velocità a 64K è sostanzialmente in pari** con il 9B: prefill equivalente a profondità piena, ma generazione più lenta (18,4 contro 26,3 token/s). Un eventuale passaggio al 20B va giustificato dalla **qualità/capacità agentica superiore** (20B MoE, function-calling e reasoning a livelli), non dalla latenza. Prossimo passo per decidere: confronto di qualità diretto su task Hermes reali (multi-step, tool multipli) tra Qwen 3.5 9B e GPT-OSS 20B. Fino ad allora il 9B resta il default per la generazione più rapida a contesto pieno.

## Scenari aggiuntivi: quant KV, quant pesi, spec decoding, reasoning budget (16 luglio 2026)

Quattro test mirati al vero collo di bottiglia a 64K (banda KV in generazione, degrado del prefill). Tutti su build `b10038`, Flash Attention attiva. Lo script `bench-prefill.ps1` è stato esteso con i parametri `-KvType` (q8_0/q4_0/f16) e `-Quick` (solo i punti sensibili alla KV: depth 0, depth 64K, gen 64K).

**1. Cache KV Q4 invece di Q8** — risultato negativo. Il kernel flash-attn su Arc Vulkan dequantizza `q4_0` durante l'attention: il prefill a 64K peggiora, la generazione guadagna solo pochi punti percentuali.

| Metrica @ 64K | Qwen 9B Q8 → Q4 | GPT-OSS 20B Q8 → Q4 |
|---|---|---|
| prefill | 164,1 → 138,7 token/s (−15%) | 156,7 → 147,4 token/s (−6%) |
| generazione | 26,5 → 28,3 token/s (+7%) | 18,4 → 19,1 token/s (+4%) |

Inoltre libera solo ~1-2 GiB, insufficiente a far entrare modelli più grandi, e degrada la qualità. **Si conserva KV Q8.**

**2. Qwen 9B a quantizzazione superiore (Q6_K)** — entra comodo (6,84 GiB) ma non conviene per la latenza.

| Metrica | Q4_K_M | Q6_K | Delta |
|---|---:|---:|---|
| prefill @ depth 0 | 685,5 token/s | 510,6 token/s | −25% |
| prefill @ depth 64K | 164,1 token/s | 151,4 token/s | −8% |
| generazione @ depth 64K | 26,5 token/s | 20,7 token/s | −22% |

Il guadagno di qualità di Q6_K su Q4_K_M per un 9B è marginale (pochi decimi di perplexity), a fronte di un −22% di velocità di generazione. **Si conserva Q4_K_M.**

**3. Speculative decoding (Qwen 9B target + draft Qwen 3.5 0.8B Q8)** — guadagno modesto ma quasi gratuito. Prova con `llama-cli -md`, task di coding, greedy (`--temp 0`, massimo tasso di accettazione), `--spec-draft-n-max 8`, contesto 4K:

| Configurazione | Generazione |
|---|---:|
| solo 9B | 39,3 token/s |
| 9B + draft 0.8B | 42,9 token/s (+9%) |

Il draft occupa solo ~0,8 GiB di VRAM. Vincolo: funziona solo con target della stessa famiglia (vocabolario condiviso), quindi **Qwen sì, GPT-OSS no** (vocabolario diverso, nessun draft piccolo compatibile). Il beneficio dipende dal workload e a 64K è probabilmente inferiore perché anche il draft rallenta con la profondità. Opzionale: si può aggiungere `--model-draft` al launcher del 9B per un +9% quasi gratis.

**4. Reasoning budget di GPT-OSS 20B** — leva reale sulla latenza. Stesso task di ragionamento (risposta corretta in tutti i casi), `reasoning_effort` variato via richiesta:

| effort | completion_tokens | lunghezza reasoning | tempo generazione |
|---|---:|---:|---:|
| low | 298 | 589 | 5,19 s |
| medium | 350 | 784 | 6,09 s |
| high | 350 | 784 | 6,08 s |

La generazione resta ~57 token/s a basso contesto (più rapida del 9B a contesto ridotto, ma il 20B crolla a ~18 token/s a 64K). La latenza per-turno dipende dai token di reasoning: `reasoning_effort=low` taglia circa il 15% rispetto a medium/high senza perdere correttezza su task semplici (medium ed high coincidono qui). Se si adotta GPT-OSS, usare `reasoning_effort=low`.

**Sintesi degli scenari:** nessuna variante di quantizzazione batte la configurazione attuale. Il default ottimale resta **Qwen 3.5 9B Q4_K_M con cache KV Q8**. Unico ritocco additivo utile e a basso costo: draft 0.8B per speculative decoding sul server 9B (+9% generazione, +0,8 GiB VRAM). Se in futuro si passa a GPT-OSS 20B per la qualità, impostare `reasoning_effort=low` per contenere la latenza.

## Offload MoE-aware con --n-cpu-moe: correzione al verdetto Gemma (16 luglio 2026)

I test online hanno evidenziato un errore di metodo nel confronto precedente su Gemma 26B-A4B: era stato lanciato con `-ngl 99`, che tenta di mettere tutto in VRAM e provoca uno spill caotico in RAM quando il modello + KV 64K superano i 16 GB. Per i modelli **MoE** la strategia corretta è `--n-cpu-moe N` (alias `-ncmoe`): mantiene in VRAM attention, cache KV e layer condivisi, e sposta in RAM solo gli **esperti instradati**. Attraverso il PCIe passa solo il piccolo vettore di attivazione, non i pesi degli esperti.

Il meccanismo è stato validato su Arc Vulkan (build b10038) usando GPT-OSS 20B, che è MoE. Forzando tutti gli esperti su CPU (`-ncmoe 99`) contro il modello interamente in VRAM:

| Metrica | tutto in VRAM | esperti su CPU (-ncmoe 99) | Delta |
|---|---:|---:|---|
| prefill @ depth 0 | 942,2 token/s | 373,1 token/s | −60% |
| prefill @ depth 64K | 156,7 token/s | 114,2 token/s | −27% |
| generazione @ depth 64K | 18,4 token/s | 10,7 token/s | −42% |

Il dato decisivo è il confronto del prefill a 64K fra i due metodi di offload:

- Gemma con offload naive (`-ngl 99`): **37,5 token/s** (circa 17 minuti per riempire 64K);
- GPT-OSS con offload MoE-aware (`-ncmoe`): **114,2 token/s** anche con tutti gli esperti in RAM.

Circa **3 volte** più veloce nel prefill, perché attention e KV restano sui ~560 GB/s della VRAM invece di finire nella RAM DDR4-3600 (~57,6 GB/s, circa 10 volte più lenta). Il prefill a 64K — il vero collo di bottiglia di Hermes — con l'offload MoE-aware non crolla più; la generazione paga il costo della via CPU per gli esperti (qui ~10,7 token/s con 3,6B parametri attivi).

**Conseguenza:** il verdetto "Gemma 26B-A4B inutilizzabile a 64K" era un artefatto del metodo di offload sbagliato. Con `--n-cpu-moe` un MoE che sfora la VRAM torna praticabile: prefill in VRAM, esperti in RAM. Nota operativa: `llama-bench` e `llama-server` accettano `-ncmoe N`; la build `b10038` espone anche `--cpu-moe` (tutti gli esperti su CPU) e `-ot/--override-tensor` per il controllo fine dei tensori.

### Prova su Gemma 26B-A4B: tecnica veloce ma bloccata da un bug upstream

Gemma 4 26B-A4B è stata riscaricata (era stata cancellata dal disco) e provata con offload MoE-aware su `llama-server`, contesto 65536, `--n-cpu-moe 24`, KV Q8, Flash Attention. Il modello carica correttamente e il prefill parte veloce:

| Build | prefill misurato prima del crash |
|---|---|
| b10038 | ~108 → 136 token/s (in salita) |
| b10042 | ~150 → 160 token/s |

Quindi il metodo corretto porta il prefill di Gemma a 64K da **37 token/s (offload naive)** a **~150-160 token/s** — circa 4 volte più veloce, come previsto, perché attention e KV restano in VRAM.

Tuttavia entrambe le build **crashano durante il prefill lungo** con:

```
GGML_ASSERT(id >= 0 && id < n_expert) failed  (ggml-backend.cpp:1615)
```

Il crash arriva a contesto parziale (circa 10-20% dei 64K) ed è un **bug noto e ancora aperto** di llama.cpp ([issue #18786](https://github.com/ggml-org/llama.cpp/issues/18786)), legato alla validazione degli id degli esperti nell'offload MoE. È presente sia in `b10038` sia nell'ultima `b10042` (16 luglio 2026). GPT-OSS 20B con lo stesso `-ncmoe` invece **non** crasha (completa i 64K), ma essendo già interamente in VRAM non trae vantaggio dall'offload.

**Stato di questa via:** l'offload MoE-aware (`--n-cpu-moe`) è la tecnica giusta e veloce per far girare a 64K un MoE più grande della VRAM, ma per Gemma 4 è bloccata da un bug upstream non ancora risolto. Da riprovare quando la issue #18786 sarà chiusa in una build successiva, oppure con un MoE grande diverso non affetto dal bug. Fino ad allora il default resta Qwen 3.5 9B Q4_K_M (+ draft 0.8B opzionale) e GPT-OSS 20B come alternativa di qualità già utilizzabile.

### Tentativi di aggirare il bug: backend SYCL e micro-batch ridotto

Provate due strade per sbloccare Gemma 4 + `--n-cpu-moe` a 64K, entrambe fallite nel dare una configurazione realmente usabile.

**Backend SYCL (b10042, Level Zero, Arc):** non crasha (il bug è specifico dei kernel MoE Vulkan), il prefill lungo procede oltre il punto di crash di Vulkan e con **output corretto**. Ma il prefill con esperti su CPU è lento: **~52 token/s costanti**, cioè circa **21 minuti** per riempire 64K. Troppo lento per Hermes. L'env var Intel raccomandata `SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1` (dall'articolo Intel «Run LLMs on Intel GPUs Using llama.cpp») porta il prefill a **~75 token/s** (+45%) mantenendo output corretto, ma la generazione resta molto bassa (~4-12 token/s): comunque non praticabile a 64K. Nota: IPEX-LLM è stato scartato perché in test recenti risulta più lento dello SYCL standard.

**Micro-batch ridotto su Vulkan (`--ubatch-size 256`):** evita il crash duro fino ai 64K pieni (65387 token processati senza assert). Ma:

- il prefill medio su 64K è **~54 token/s** (circa 20 minuti a freddo), nessun guadagno rispetto a SYCL o all'offload naive;
- soprattutto, **l'output a 64K è corrotto**: parole storpiate e malformate (es. «frsi», «ripetutute», «centosettantaantqu»), mentre a basso contesto lo stesso server produce testo pulito.

La corruzione a profondità con `-ub 256`, contro il crash con `-ub 512`, indica che il micro-batch non risolve il bug ma ne cambia solo il sintomo: il routing degli esperti resta errato sotto offload MoE su Vulkan, producendo esperti sbagliati (testo corrotto) invece dell'assert. Nessuna delle due strade rende Gemma 4 usabile a 64K.

**Conclusione consolidata:** su questo stack, oggi, un MoE più grande della VRAM a 64K non è praticabile — Vulkan corrompe/crasha nell'offload MoE, SYCL è troppo lento. La tecnica `--n-cpu-moe` resta valida in linea di principio (prefill in VRAM veloce quando funziona, come su GPT-OSS che completa i 64K senza problemi) ma richiede la correzione a monte del kernel MoE Vulkan di llama.cpp per Gemma 4. Default operativo confermato: **Qwen 3.5 9B Q4_K_M + KV Q8 (+ draft 0.8B opzionale)**, con **GPT-OSS 20B** come alternativa di qualità già utilizzabile.

### Tentativi di flag e localizzazione della causa

Prima di scartare la via, sono stati provati flag/env economici sul path Vulkan (nessuno risolve, spostano solo il sintomo):

- `GGML_VK_DISABLE_FUSION=1`: nessun effetto, crash sempre a ~8K token;
- `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1`: sposta il crash da ~8K a ~22,5K, output corretto fino a lì e prefill ~115-125 token/s, ma poi stesso assert;
- `--ubatch-size 256`: nessun assert fino a 64K, ma output corrotto ad alto contesto.

Lo spostamento del crash col path di memoria localizza il difetto: la riga `ggml-backend.cpp:1615` legge gli id degli esperti copiandoli in modo asincrono dal backend Vulkan (`ggml_backend_tensor_get_async` + `ggml_backend_synchronize`) e poi li valida. Le cause probabili sono una race di sincronizzazione della copia async o un problema di offset/stride del tensore ids sul backend Vulkan (SYCL usa un path diverso e non crasha). L'analisi completa è stata inserita nel report `llamacpp-issue-gemma-moe.md`, pronto da postare come issue upstream. Il fix definitivo richiede una patch al sorgente e una build locale (toolchain Vulkan+CMake), non risolvibile via configurazione. La segnalazione è stata poi pubblicata come [issue #25777](https://github.com/ggml-org/llama.cpp/issues/25777), con un commento aggiuntivo che riporta la localizzazione della causa.

## OVMS / OpenVINO su Arc: stack Hermes completo e prestazioni superiori (16 luglio 2026)

Ripreso il percorso OpenVINO abbandonato il 15 luglio, perché OVMS (OpenVINO Model Server) 2026 ha risolto i bloccanti di allora. È stato usato il pacchetto **Windows nativo** `ovms_windows_2026.2.1_python_on.zip` (versione Python-enabled, necessaria per il tool calling) — niente più Docker/WSL/LFS. Modello: `OpenVINO/Qwen3.5-9B-int4-ov`, servito su GPU Arc.

Comando di avvio funzionante (dalla cartella OVMS, dopo `setupvars`):

```
ovms --model_path <modello_ov> --model_name qwen --task text_generation \
     --target_device GPU --rest_port 8000 \
     --tool_parser hermes3 --reasoning_parser qwen3 \
     --enable_tool_guided_generation true --enable_prefix_caching true \
     --cache_size 8
```

Dettagli di configurazione emersi (i «trucchi» che sbloccano tutto):

- **tool parser**: il valore corretto per Qwen 3.5 è `hermes3` (non `hermes` né `qwen3`, che danno «Unsupported tool parser»);
- **tool calling affidabile**: richiede `--enable_tool_guided_generation true`; senza, il modello «pensa» di dover chiamare la funzione ma non emette il blocco `<tool_call>` e `tool_calls` resta vuoto;
- **reasoning off**: si ottiene per richiesta con `"chat_template_kwargs": {"enable_thinking": false}`; il campo `reasoning_parser qwen3` separa comunque il thinking in `reasoning_content`;
- **generazione veloce**: fondamentale `--cache_size 8` (KV cache preallocata da 8 GB). Con il default `cache_size=0` la KV cache è dinamica e si rialloca in continuazione, crollando la generazione a ~1,5 token/s; con la cache fissa sale a ~47 token/s;
- **prima chiamata lenta**: la prima richiesta per una nuova shape paga la compilazione dei kernel GPU (prefill 40K: 262 s a freddo contro ~29 s a caldo). OVMS mantiene una cache dei kernel; a regime è veloce.

Stack Hermes verificato end-to-end su Arc:

- **reasoning off** → risposta pulita e corretta (`17*23 = 391`), `finish_reason: stop`;
- **tool calling** → `finish_reason: tool_calls`, funzione `get_weather`, argomenti `{"city":"Roma"}`;
- **streaming SSE** → chunk `chat.completion.chunk` in formato OpenAI corretto.

Prestazioni misurate (Qwen 3.5 9B int4, Arc A770, a caldo):

| Metrica | OVMS / OpenVINO | llama.cpp Vulkan (b10002) |
|---|---:|---:|
| prefill a ~33-40K token | **~1355-1620 token/s** (64K in ~40-48 s) | ~163 token/s @ 64K |
| generazione a basso contesto | **~47 token/s** | ~40 token/s |
| generazione a profondità ~33K | **~40 token/s** | ~26 token/s @ 64K |

OpenVINO/OVMS **supera llama.cpp su tutti gli assi** — prefill circa 8-10 volte più rapido, generazione più veloce sia a vuoto sia a profondità, e nessun bug MoE (runtime diverso). Inoltre offre già le funzioni richieste da Hermes (reasoning off, tool calling, streaming) native su Windows.

**Implicazioni:**

- Anche restando sul 9B, spostare Hermes da llama.cpp a OVMS dà un guadagno enorme sul prefill (il vero collo di bottiglia a 64K) mantenendo o migliorando la generazione;
- OVMS apre la porta a un **modello più grande** a 64K (Gemma 4, Qwen 3.6, MoE grandi) senza il muro del prefill Vulkan né il bug MoE: prossimo passo naturale, convertendo/scaricando il modello in formato OpenVINO;
- restano da valutare per la produzione: autenticazione (`--api_key_file`), esposizione LAN, e la conversione del modello scelto in formato OV (via `optimum-intel` o modelli pre-convertiti sul repository `OpenVINO/` di Hugging Face).

### Modelli più grandi su OVMS: il muro VRAM regge anche per OpenVINO

Provati due modelli Qwen 3.6 più grandi in formato OpenVINO int4 su Arc via OVMS, per centrare l'obiettivo del modello di qualità superiore a 64K:

| Modello | Pesi (language model) | Generazione | Esito |
|---|---:|---:|---|
| `OpenVINO/Qwen3.5-9B-int4-ov` | 5,8 GB | ~47 token/s | entra in VRAM, veloce |
| `OpenVINO/Qwen3-14B-int4-ov` (denso) | 9,1 GB | — | **crasha in inferenza** (`CL_OUT_OF_RESOURCES`) |
| `OpenVINO/Qwen3.6-27B-int4-ov` (denso) | 13,9 GB | ~1,3 token/s | spilla, inutilizzabile |
| `OpenVINO/Qwen3.6-35B-A3B-int4-ov` (MoE) | 18,6 GB | ~0,6 token/s | spilla, inutilizzabile |

Il 14B è il caso più netto: i pesi int4 espansi in VRAM + i buffer di lavoro del plugin GPU OpenVINO + la VRAM già occupata dal desktop Windows superano i 16 GB effettivi, quindi il server carica (`AVAILABLE`) ma **muore già sulla richiesta di warm-up** con `[GPU] clFlush, error code: -5 CL_OUT_OF_RESOURCES`, a qualunque `cache_size` (6 rifiutato al load per "budget > available memory", 3 e 2 caricano ma crashano in inferenza). Non è questione di contesto: non regge nemmeno un "ciao".

I due modelli 27B/35B invece caricano e rispondono (OVMS li porta ad `AVAILABLE` sfruttando la shared GPU memory di Windows), ma la generazione crolla perché **OpenVINO sul plugin GPU sposta l'intero modello in RAM condivisa quando eccede la VRAM**, senza l'offload selettivo dei soli esperti attivi che fa `--n-cpu-moe` in llama.cpp. Superati circa 11-12 GB di footprint, il decode diventa dominato dalla banda della RAM (~57 GB/s) e scende a 1 token/s.

**Conclusione sul dimensionamento (Arc A770 16 GB):**

- il modello più grande che gira *veloce* via OVMS resta nella fascia ~6 GB di pesi (il 9B è il punto ottimale); già il 14B (9,1 GB) non entra proprio in inferenza (`CL_OUT_OF_RESOURCES`), quindi il divario 9B→27B **non è colmabile** su questa GPU con la sola VRAM;
- per un modello genuinamente più grande a 64K servirebbe l'offload selettivo MoE (`--n-cpu-moe` di llama.cpp), che è veloce ma per Gemma 4 è bloccato dal bug Vulkan (issue #25777), oppure più VRAM;
- il guadagno concreto e già disponibile resta enorme: **portare Hermes sul 9B servito da OVMS** dà prefill ~10× e generazione più veloce rispetto a llama.cpp, con tutte le funzioni (reasoning off, tool calling, streaming) — indipendentemente dalla taglia del modello.

### Il fallimento del 14B è un limite di OpenVINO, non dell'hardware

Ricerca online (luglio 2026) dopo il crash del 14B: il problema non è la GPU ma il tool.

- **`CL_OUT_OF_RESOURCES` è un bug noto e aperto del plugin GPU OpenVINO** (issue [#36187](https://github.com/openvinotoolkit/openvino/issues/36187), [#35723](https://github.com/openvinotoolkit/openvino/issues/35723)) — non risolto da Intel da 6+ mesi, sensibile al driver, non sempre pura mancanza di memoria.
- **OpenVINO sul plugin GPU è tutto-o-niente:** se modello + buffer non entrano in VRAM crasha secco, non sa scaricare layer su CPU come fa llama.cpp con `-ngl` parziale. Questo spiega perché il 14B (denso, 9,1 GB pesi) muore mentre il 27B (che spilla in shared memory) almeno risponde, seppur a 1 t/s.
- Fonti indipendenti confermano che **A770 16 GB fa girare Qwen 14B Q4 a ~21 token/s con llama.cpp** ([localaimaster](https://localaimaster.com/blog/intel-arc-a770-local-ai), [insiderllm](https://insiderllm.com/guides/intel-arc-local-ai/)). Quindi il 14B *gira* — ma via llama.cpp, non OVMS.

**Conseguenza pratica per il 14B:** girerebbe su llama.cpp (Vulkan b10002, modello denso → nessun bug MoE), ma a 64K **resuscita il muro del prefill Vulkan** (~100-150 t/s contro i ~1620 di OVMS) e la generazione scende a ~15-21 t/s. Cioè: modello più intelligente, esperienza più lenta del 9B su OVMS. Per Hermes (contesti lunghi + tool) il prefill lento pesa. Da misurare empiricamente prima di adottarlo.

**Sui bug:**
- il bug OpenVINO (#36187) non è nostro né correggibile — plugin GPU compilato di Intel;
- il bug llama.cpp MoE Vulkan (#25777) è open source e correggibile, ma anche fixato sblocca solo Gemma-MoE con offload CPU = ~1 t/s, quindi non conviene;
- **fixare i bug non abbatte il muro VRAM:** il 27B non ha bug e gira comunque a 1,3 t/s. Il vero blocco per un modello *grande e veloce* è la VRAM fisica, non il software. Le uniche vie reali: seconda A770 (FlashMoE per 30B+), GPU con più VRAM (24 GB+), o restare sul 9B veloce.

### Nuovo lever disponibile: INT4 KV cache (OVMS 2026.2)

OpenVINO 2026.2 aggiunge la compressione **INT4 della KV cache** sul plugin GPU: `KV_CACHE_PRECISION: u4` (in OVMS il flag corrispondente al posto di `u8`). Taglia la KV **~44% vs u8** e ~68% vs fp16, con accuratezza equivalente su modelli già a pesi int4 (come il nostro Qwen). Utile per **estendere la profondità di contesto** a parità di VRAM, ma **non salva il 14B** (che crasha al warm-up con KV vuota — il problema sono i pesi+buffer base, non la KV). Buon candidato per il futuro se servisse più margine di contesto sul 9B.

### OpenVINO nativo: fascia 12B-14B

Test del 16 luglio 2026, OpenVINO/GenAI nightly 2026.4, senza Docker.

- **Qwen3 14B INT4:** `HETERO:GPU,CPU` compila in 17,9 s ma fallisce in inferenza con `CL_OUT_OF_RESOURCES`. `HETERO:CPU,GPU` funziona, carica in 4,5 s e genera circa **2,2 token/s**; con `/no_think`, `17 * 23` restituisce `391`. È funzionale ma troppo lento per Hermes.
- **Gemma 3 12B INT4:** gira interamente sulla Arc A770 tramite `VLMPipeline`, occupa 7,55 GB, carica in 16,7 s, TTFT 217 ms e genera **24,16 token/s**; 128 token richiedono 5,47 s e `17 * 23` restituisce `391`.

Gemma 3 12B è la fascia intermedia concreta: circa metà della velocità del Qwen 9B (~47 token/s), ma oltre dieci volte più rapido del Qwen 14B HETERO. Restano da confrontare qualità, tool calling e contesti lunghi prima dell'adozione come server principale.
