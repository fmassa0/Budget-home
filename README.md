# Bilancio Casa

App web gratuita per gestire le finanze personali e di coppia.

- **Hosting:** GitHub Pages (gratis)
- **Login e database:** Supabase (gratis)

## Funzioni
- Spazio personale privato + spazio condiviso (es. "Casa") con codice invito
- Movimenti (entrate/uscite), categorie e conti personalizzabili
- Spese ricorrenti mensili registrate in automatico
- Budget per categoria con avvisi all'80% e al 100%
- Obiettivi di risparmio con versamenti
- Spazio condiviso: chi ha pagato, divisione 50/50 o personalizzata, "chi deve a chi", rimborsi
- Dashboard con saldo del mese, grafico a torta, andamento 12 mesi
- Previsione di fine mese (ritmo di spesa + ricorrenti ancora da pagare) e prossime scadenze
- Approfondimenti automatici (categorie fuori media, spesa più grande, % risparmiata, ricorrenti attive)
- Foto dello scontrino: totale, data, negozio e categoria letti in automatico sul telefono (gratis, la foto non viene inviata)
- Spese frequenti: un tocco e il movimento è già compilato
- Export Excel e PDF, import estratto conto CSV/Excel (con categorie automatiche)
- Tema chiaro/scuro, installabile sul telefono, aggiornamento in tempo reale tra i due telefoni

## File
| File | Cosa contiene |
|---|---|
| `index.html` | l'app |
| `config.js` | **qui vanno URL e chiave di Supabase** |
| `schema.sql` | script del database da eseguire una volta su Supabase |
| `manifest.json`, `sw.js`, `icon*.png`, `icon.svg` | installazione sul telefono |

## Passo 1 – Supabase (database e login)
1. Registrati su [supabase.com](https://supabase.com) → **New project** (regione Europa, es. Frankfurt).
2. **SQL Editor → New query** → incolla tutto il contenuto di `schema.sql` → **Run**.
3. **Project Settings → API** (o *Data API*): copia **Project URL** e la chiave pubblica **anon / publishable**.
4. Apri `config.js` qui su GitHub (icona matita ✏️), incolla i due valori tra le virgolette e salva (**Commit changes**).

## Passo 2 – Pubblicazione
1. Repository → **Settings → Pages** → *Deploy from a branch* → `main` / `(root)` → **Save**.
2. Dopo 1–2 minuti l'app è su `https://TUONOMEGITHUB.github.io/bilancio-casa/`
3. Supabase → **Authentication → URL Configuration**: incolla quell'indirizzo in **Site URL** e in **Redirect URLs**.

## Passo 3 – Uso in coppia
1. Registrati: lo spazio "Personale" si crea da solo.
2. **Altro → Spazi e condivisione → Crea spazio condiviso** (es. "Casa"): compare un codice invito di 8 caratteri, che puoi inviare con WhatsApp.
3. La compagna si registra → **Altro → Spazi → Ho un codice invito** → inserisce il codice.
4. Sul telefono: Safari → Condividi → **Aggiungi a Home** (iPhone) oppure Chrome → ⋮ → **Installa app** (Android).

## Note
- Il repository può essere pubblico: nel codice c'è solo la chiave **pubblica** di Supabase. I dati sono protetti dalle regole di sicurezza del database (ognuno vede solo gli spazi di cui fa parte).
- Il piano gratuito di Supabase mette in pausa i progetti inutilizzati per una settimana: basta riattivarlo dalla dashboard.
- "Quota a carico di chi ha pagato": 50% = si divide a metà; 100% = la spesa è solo di chi ha pagato; 0% = è tutta dell'altro.
