# RamanFit — Manuale utente

`RamanFitApp.m` è un'applicazione MATLAB (App Designer, finestra singola) per
il fit di spettri Raman sperimentali con somme di funzioni di picco, con
sottrazione del fondo, smoothing e normalizzazione come passaggi opzionali di
preprocessing.

Non fa parte del toolbox G09/G16 di analisi degli output di Gaussian: lavora
su dati **sperimentali** (misure reali), non su risultati di calcoli quantistici.

## Requisiti

- MATLAB con **Optimization Toolbox** (per `lsqcurvefit`, il motore di fit)
- **Signal Processing Toolbox** (per `sgolayfilt`, lo smoothing Savitzky-Golay)
- Nessuna dipendenza esterna al di fuori di MATLAB: tutte le funzioni di
  supporto (`gausslor.m`, `backcor.m`, `airPLS.m`, `readdpt.m`) sono incluse
  nella cartella `RamanFit/` stessa.

## Avvio

```matlab
RamanFitApp()              % finestra vuota, poi "Load spectrum..."
RamanFitApp('spettro.txt') % carica subito il file indicato
```

## Formati di file supportati

| Estensione | Formato | Note |
|---|---|---|
| `.txt`, `.csv`, `.dat` | Due colonne, delimitatore spazio/tab/virgola, con o senza intestazione | Letto con `readmatrix` |
| `.dpt` | Due colonne separate da virgola, senza intestazione (tipico export OPUS/Bruker) | Letto con `readdpt.m` |

In entrambi i casi la prima colonna è il numero d'onda (asse X), la seconda
l'intensità (asse Y). I dati vengono automaticamente ordinati per X
crescente al caricamento.

## Più spettri contemporaneamente

**Load spectrum...** aggiunge un nuovo spettro invece di sostituire quello
corrente. Il menu a tendina **Spectra:** nella barra laterale elenca tutti
gli spettri caricati nella sessione: selezionandone uno si passa a
lavorarci, ripristinando esattamente lo stato in cui era stato lasciato —
dati grezzi/di lavoro, range di analisi, picchi, tabella dei risultati,
statistiche e, se era stato eseguito un fit, anche la curva totale (e
l'eventuale fondo fittato) sul grafico.

## Struttura della finestra

- **Grafico principale** (in alto a destra): spettro grezzo (grigio), spettro
  "di lavoro" dopo le elaborazioni (blu), overlay del fondo (arancione
  tratteggiato), curva di fit totale (rossa), componenti dei singoli picchi
  (tratteggiate, un colore diverso per ciascun picco — vedi
  [Marker dei picchi sul grafico](#marker-dei-picchi-sul-grafico)).
- **Grafico dei residui** (sotto, più piccolo): `dato - fit` dopo ogni fit,
  con asse X agganciato al grafico principale (zoom/pan sincronizzati).
- **Barra laterale**: pulsante di caricamento, selettore del range di
  analisi, pulsante **Reset Y axis** (riscala l'asse Y ai soli dati nel
  range di analisi selezionato — o all'intero spettro se non ne è stato
  impostato uno — eliminando lo spazio vuoto lasciato ad es. da un residuo
  di fondo non ancora sottratto), e tre schede evidenziate (Preprocess /
  Peaks / Results).

## Range di analisi

Il **range di analisi** (cm⁻¹) restringe sia il calcolo del fondo sia il fit
alla sola finestra selezionata (se non impostato, si usa l'intero spettro).

- **Select range (drag on plot)**: premi il pulsante, poi trascina sul
  grafico da un estremo all'altro della finestra desiderata.
- I campi **Min/Max** possono anche essere digitati direttamente.
- **Zoom to range** / **Show full spectrum**: zoom della sola vista, non
  cambia quali dati entrano nel fit.
- **Clear range**: torna a usare l'intero spettro.

## Scheda Preprocess

### Baseline (sottrazione del fondo)

Quattro metodi selezionabili dal menu **Method**:

- **backcor** — stima iterativa del fondo con un polinomio e pesi
  asimmetrici. Parametri: `Order` (grado del polinomio, default 5),
  `Threshold` (default 0.1), `Cost function` (`sh`/`ah`/`stq`/`atq`, default
  `atq`).
- **airPLS** — *Adaptive Iteratively Reweighted Penalized Least Squares*.
  Parametri: `Lambda` (rigidità della curva, default 1e7 — più alto = fondo
  più liscio), `Diff ord` (ordine delle differenze penalizzate, default 2),
  `Edge wt` (peso ai bordi, default 0.1), `p (asym)` (asimmetria, default
  0.05), `Max iter` (default 20).
- **SNIP** (*Statistics-sensitive Non-linear Iterative Peak-clipping*) —
  concettualmente diverso dagli altri due: non fa un fit polinomiale né usa
  pesi iterativi, "rasa" ogni punto al valor medio dei suoi vicini a
  distanza crescente, fino a lasciare solo variazioni lente. Parametri:
  `Iterations (M)` (default 40 — quante iterazioni/distanza massima:
  qualunque struttura più stretta di ~M punti viene trattata come picco,
  non come fondo), `Use LLS transform` (default attivo — comprime la
  dinamica del segnale prima del clipping, utile se ci sono picchi di
  altezza molto diversa nello stesso spettro).
- **APLS** (*Adaptive-weight Penalized Least Squares*, Cadusch et al.
  2013) — come `airPLS`, un fit a spline penalizzata (Whittaker), ma con
  un peso adattivo più semplice e statisticamente motivato: a ogni
  iterazione, il peso di ciascun punto è la probabilità che il valore
  osservato provenga per caso dal solo fondo (rumore Poissoniano), dato il
  fondo stimato al passo precedente — punti ben sopra il fondo (probabili
  picchi Raman) pesano poco, punti a livello del fondo pesano ~1. Nel
  paper originale risulta il metodo più accurato su fondi complessi
  (fluorescenza strutturata). Parametri: `Gamma` (rigidità della curva,
  default 1e5 — scala molto con i dati, va tipicamente regolato caso per
  caso, come `Lambda` per `airPLS`), `Diff ord` (1 o 2, default 2 — la
  variante raccomandata dagli autori), `Max iter` (default 10).

Flusso di lavoro: **Preview baseline** disegna il fondo stimato come overlay
senza modificare i dati; **Subtract baseline** lo sottrae effettivamente
dallo spettro di lavoro. Il calcolo rispetta il range di analisi corrente.

### Smoothing (Savitzky-Golay)

Parametri: `Window length` (lunghezza finestra, dispari, default 11),
`Poly order` (grado del polinomio locale, default 3). Stesso flusso
Preview/Apply del fondo: **Preview smoothing** mostra il risultato senza
applicarlo, **Apply smoothing** lo conferma.

Nota: confermare fondo o smoothing invalida automaticamente un'eventuale
anteprima non confermata dell'altro (evita overlay non più coerenti con i
dati aggiornati).

### Normalization

Menu **Method**: `None` / `Max = 1` (divide per il massimo nella finestra di
analisi corrente) / `Area = 1` (divide per l'area integrata nella stessa
finestra). Utile per confrontare spettri diversi su una scala comune.

### Reset to raw

Riporta lo spettro di lavoro ai dati grezzi originali, cancellando fondo,
smoothing, normalizzazione, picchi e risultati del fit.

## Scheda Peaks

### Aggiungere picchi

Premi **Add peak**, poi clicca sul grafico nel punto desiderato: viene
creato un picco Gaussiano con centro nel punto cliccato, altezza pari al
valore dei dati in quel punto, e una larghezza iniziale di stima.

### Marker dei picchi sul grafico

Ogni picco della tabella è mostrato sul grafico con due marker colorati
(stesso colore della curva del picco, ciclando sulla palette di default di
MATLAB), entrambi trascinabili col mouse per correggere a occhio la stima
iniziale prima del fit:

- **Marker di posizione** (triangolo, con etichetta numerica del valore di
  Center sopra): trascinandolo si aggiornano sia **Center** (orizzontale)
  sia **Height** (verticale) nella tabella.
- **Marker FWHM** (cerchio, con etichetta sotto), posizionato al punto di
  metà altezza del picco (Center + FWHM/2, Height/2): trascinandolo
  **solo orizzontalmente** si aggiorna FWHM = 2 × (distanza dal centro).

Al rilascio del mouse, la curva tratteggiata di quel picco si ridisegna
subito con i nuovi valori (per le forme con un parametro extra — Fano,
Pearson VII, True Voigt — riusa l'ultimo valore fittato se ancora
compatibile, altrimenti una stima di default ragionevole), così l'effetto
della modifica è visibile immediatamente senza dover rilanciare il Fit.

### Tabella dei picchi

| Colonna | Significato |
|---|---|
| Shape | Forma del picco (menu a tendina per riga, vedi sotto) |
| Center, FWHM, Height | Parametri base, editabili direttamente (o trascinando i marker sul grafico, vedi sopra) |
| Fix (accanto a Center/FWHM/Height) | Se spuntato, blocca quel parametro al suo valore corrente durante il fit (vince su eventuali Min/Max) |
| C.Min/C.Max, F.Min/F.Max, H.Min/H.Max | Limiti opzionali per il fit — lasciare vuoto per usare i limiti di default |

I limiti di default sono: Height ≥ 0, FWHM tra il doppio della spaziatura
tipica dei dati e l'intera larghezza dello spettro (evita che un picco
collassi su un singolo punto rumoroso), Center entro il range dei dati (o
del range di analisi, se impostato).

### Forme dei picchi disponibili

| Forma | Parametri | Note |
|---|---|---|
| Gaussian | I, FWHM, x₀ | |
| Lorentzian | I, FWHM, x₀ | |
| Pseudo-Voigt | I, FWHM, x₀, `Lor` (0–1) | Combinazione Gauss-Lorentz; `Lor`=0 Gaussiana pura, `Lor`=1 Lorentziana pura |
| Fano | I, FWHM, x₀, `q` | Lineshape Breit-Wigner-Fano, per bande asimmetriche (es. materiali carboniosi); `q` grande → Lorentziana |
| Pearson VII | I, FWHM, x₀, `m` | `m`=1 → Lorentziana esatta, `m` grande → Gaussiana esatta |
| True Voigt | I, FWHM (=FWHM Gaussiana), x₀, `FWHM_L` (Lorentziana) | Convoluzione vera Gauss⊗Lorentz, calcolata per integrazione numerica (non l'approssimazione pseudo-Voigt) |

Ogni riga della tabella può usare una forma diversa: il fit può quindi
mescolare forme diverse nello stesso spettro.

### Background (fondo fittato insieme ai picchi)

Menu **Background**: `None` / `Constant` / `Linear` / `Quadratic` / `Cubic`.
A differenza della sottrazione del fondo in Preprocess (fatta *prima* e poi
fissata), qui i coefficienti del polinomio vengono stimati **insieme** ai
picchi nella stessa ottimizzazione — utile quando fondo e picchi sono
difficili da separare a priori. Il fondo stimato appare come curva
punteggiata sul grafico.

### Fit

Il pulsante **Fit** si disabilita e mostra "Fitting..." durante
l'esecuzione. Al termine mostra di nuovo "Fit", sia in caso di successo
che di errore.

Durante il fit la barra di stato in basso mostra in tempo reale
l'iterazione corrente e il valore di chi-quadro (`chi^2 = SSE`), utile per
valutare l'andamento della convergenza. Accanto a **Fit** compare anche
**Stop fit**: interrompe l'ottimizzazione mantenendo il miglior risultato
trovato fino a quel momento, senza generare un errore — equivalente a un
fit che si è fermato naturalmente a quell'iterazione.

Il motore è `lsqcurvefit` (somma dei quadrati degli scarti, non pesata),
con tolleranze strette e limiti di iterazione generosi per assicurare la
convergenza in un solo click.

## Scheda Results

### Tabella dei risultati

Colonne: `Peak`, `Shape`, `Center` (± errore), `FWHM` (± errore), `Height`
(± errore), `Area` (calcolata per integrazione numerica, valida per
qualunque forma).

Gli **errori** (colonne "+/-") sono stime standard per i minimi quadrati
non lineari: `Cov(θ) = σ²·(JᵀJ)⁻¹` con `σ² = SSE/dof`, dalla Jacobiana di
`lsqcurvefit` nel punto di minimo. Un parametro con **Fix** attivo ha
errore esattamente `0` (non viene stimato, non consuma un grado di
libertà). Se la matrice è troppo mal condizionata (parametri fortemente
correlati, al limite di un vincolo, o — per un solo parametro — localmente
insensibile al modello in quel punto, es. un True Voigt il cui fit è
scivolato quasi interamente su una delle due larghezze) l'errore è
riportato come `NaN` per il/i solo/i parametro/i coinvolto/i, invece di un
numero fuorviante, senza compromettere gli errori degli altri parametri.

### Pannello statistiche

Dopo ogni fit: numero di punti, numero di parametri, gradi di libertà,
chi-quadro (SSE), chi-quadro ridotto, R², errore RMS, e — se è stato
fittato un fondo — i suoi coefficienti.

### Esportazione

- **Export results (CSV)...** — tabella dei risultati in CSV.
- **Save fit figure...** — il grafico principale in PDF/PNG.
- **Save data (.mat)...** — vedi sezione dedicata sotto.

## Salvataggio dati (.mat)

Il file `.mat` salvato contiene:

- **`data`** (struct di curve, ognuna con campi `x`/`y`):
  - `data.raw` — sempre presente, spettro originale
  - `data.backsub` — presente se hai sottratto un fondo in Preprocess
  - `data.smoothed` — presente se hai applicato lo smoothing
  - `data.fitted` — presente dopo un fit: i dati esattamente come usati dal
    fit (include un'eventuale normalizzazione)
  - `data.background` — presente se hai fittato un fondo polinomiale
  - `data.peak1`, `data.peak2`, ... — curva di ogni singolo picco
  - `data.fit` — curva totale (somma di tutto)
- **`p1`, `p2`, ...** (una variabile per picco fittato): `I` (altezza),
  `I_err`, `w` (posizione), `w_err`, `FWHM`, `FWHM_err`, `Shape`, `Area`, e
  il parametro extra specifico della forma quando presente (`Lor` per
  pseudo-Voigt, `q` per Fano, `m` per Pearson VII, `FWHM_L` per Voigt vera).

Se non hai ancora eseguito un fit, viene salvato solo `data.raw` (ed
eventualmente `data.backsub`/`data.smoothed`) — non è necessario fittare
prima di salvare.

## Dipendenze incluse

| File | Origine | Uso |
|---|---|---|
| `gausslor.m` | libreria personale (`mymatfunctions/`) | Lineshape Gauss-Lorentz, base per Gaussian/Lorentzian/Pseudo-Voigt |
| `backcor.m` (+ `backcor_license.txt`) | V. Mazet | Metodo di sottrazione del fondo `backcor` |
| `airPLS.m` | Zhang et al. (dominio pubblico) | Metodo di sottrazione del fondo `airPLS` |
| `snip.m` | C.G. Ryan et al. 1988 (algoritmo pubblico, implementazione propria) | Metodo di sottrazione del fondo `SNIP` |
| `apls.m` | P.J. Cadusch et al. 2013 (algoritmo pubblico, implementazione propria) | Metodo di sottrazione del fondo `APLS` |
| `readdpt.m` | libreria personale (`myfileutil/`) | Lettura file `.dpt` |

Riferimenti bibliografici completi per i metodi di sottrazione del fondo
in [`REFERENCES.txt`](REFERENCES.txt).

## Limiti noti

- I fit sono minimi quadrati non pesati: ogni punto ha lo stesso peso, non
  c'è propagazione di un'incertezza di misura per punto.
- Fano e Pearson VII, avendo code molto pesanti a `q`/`m` estremi, possono
  in teoria convergere verso soluzioni degeneri se i limiti sono troppo
  larghi — il limite minimo di FWHM (legato alla spaziatura dei dati) mitiga
  il caso più comune, ma un controllo visivo del risultato resta
  raccomandato.
- Se imposti un limite Min > Max per un parametro, il fit non segnala
  errore ma restituisce il valore iniziale invariato, con gli errori
  riportati come `NaN`.
