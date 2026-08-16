# Mistři světa — plánovač natáčení

Interní webová appka pro domlouvání termínů natáčení podcastu. Každý si navolí dostupnost,
appka sama najde termíny s největším překryvem a potvrzený termín pošle jako pozvánku do Google Kalendáře.

**Co je uvnitř**

| soubor | co to je |
|---|---|
| `index.html` | celá aplikace (HTML + CSS + JS v jednom souboru, žádný build) |
| `supabase.sql` | skript, který v Supabase vytvoří všechny tabulky |
| `README.md` | tenhle návod |

---

## Rychlý přehled — co je potřeba udělat

1. Založit projekt v **Supabase** a pustit `supabase.sql` → dostaneš *URL* a *anon key*
2. Založit **OAuth klienta** v Google Cloud Console → dostaneš *Client ID*
3. Vyplnit obojí do konstant v `index.html`
4. Nahrát na **GitHub Pages**
5. Poslat odkaz kolegům

Bez kroků 1–2 appka funguje taky, jen v **ukázkovém režimu** — data se ukládají jen do jednoho
prohlížeče a nesdílí se. Na vyzkoušení stačí, na ostrý provoz ne.

---

## 1. Supabase (databáze)

1. Jdi na **[supabase.com](https://supabase.com)** → *Start your project* → přihlas se GitHubem.
2. **New project**
   - *Name*: `mistri-planovac`
   - *Database Password*: vygeneruj a někam si ulož (běžně ji nebudeš potřebovat)
   - *Region*: **Central EU (Frankfurt)**
   - *Plan*: **Free**
3. Počkej ~2 minuty, než se projekt vytvoří.
4. V levém menu **SQL Editor** → **New query**.
5. Otevři soubor `supabase.sql`, zkopíruj **celý jeho obsah**, vlož do editoru a klikni **Run**
   (nebo Cmd/Ctrl + Enter).
   Dole se má vypsat tabulka s 6 řádky — 4 moderátoři, Studio a operátor streamu. Hotovo.
6. Teď potřebuješ dva údaje:
   - V levém menu dole **Project Settings** (ozubené kolo) → **Data API** → zkopíruj **Project URL**
     (vypadá jako `https://abcdefghijkl.supabase.co`)
   - Tamtéž **API Keys** → zkopíruj klíč **`anon` / `public`** (dlouhý řetězec začínající `eyJ...`)

> **Pozn. k bezpečnosti:** `anon` klíč je veřejný — je vidět ve zdrojovém kódu stránky, tak to má být.
> Data v téhle appce nejsou citlivá (jména, e-maily kolegů a termíny). Ochranou proti náhodnému
> kolemjdoucímu je přístupový kód v appce. Kdo by anon klíč vytáhl ze zdrojáku, k datům se technicky
> dostane — proto tam nedávejte nic, co by nesmělo ven.

---

## 2. Google OAuth (pozvánky do kalendáře)

Tenhle krok je potřeba jen na tlačítko **„Odeslat pozvánku“**. Bez něj appka nabízí stažení `.ics`
souboru, který si každý naklikne do kalendáře sám.

1. Jdi na **[console.cloud.google.com](https://console.cloud.google.com)**.
2. Nahoře vlevo vytvoř **nový projekt**, např. `Mistri planovac`. Přepni se do něj.
3. V menu **APIs & Services → Library** → vyhledej **Google Calendar API** → **Enable**.
4. V menu **APIs & Services → OAuth consent screen** (novější rozhraní: *Google Auth Platform → Branding*):
   - *User type*: **External**
   - *App name*: `Mistři světa — plánovač`
   - *User support email*: tvůj e-mail
   - *Developer contact*: tvůj e-mail
   - Ulož a projdi průvodce až do konce.
5. **Audience / Test users**: dokud je aplikace ve stavu *Testing*, přidej do **Test users**
   e-maily všech, kdo budou pozvánky odesílat:
   - `franek@closefriends.cz`
   - `duda69@centrum.cz`
   - `jiritlusty11@gmail.com`
   - `jan.homolka@oneplaysport.cz`
   - `fhillnash@gmail.com` (operátor streamu — taky může rozesílat pozvánky)

   (Jde i kliknout na *Publish app* — u interní appky bez ověření se pak jen při přihlášení objeví
   obrazovka „Google hasn't verified this app“ → *Advanced* → *Go to…*. Test users je čistší cesta.)
6. **Scopes**: přidej `https://www.googleapis.com/auth/calendar.events`.
   (`userinfo.email` si Google přidá sám, používá se jen na zobrazení, kdo je přihlášený.)
7. Menu **APIs & Services → Credentials** → **Create credentials** → **OAuth client ID**
   - *Application type*: **Web application**
   - *Name*: `Mistri planovac web`
   - **Authorized JavaScript origins** — přidej přesně tyhle (bez lomítka na konci!):
     ```
     https://vildafranek.github.io
     http://localhost:8123
     ```
   - **Authorized redirect URIs**: nech prázdné (appka používá token flow, redirect nepotřebuje)
   - **Create**
8. Zkopíruj **Client ID** (končí na `.apps.googleusercontent.com`).

> Origin je jen doména, **ne** cesta. Takže `https://vildafranek.github.io`, nikoliv
> `https://vildafranek.github.io/mistri-planovac/`. Tohle je nejčastější důvod chyby
> `redirect_uri_mismatch` / `origin mismatch`.

---

## 3. Vyplnění konstant v `index.html`

Otevři `index.html` v libovolném editoru (stačí TextEdit / Poznámkový blok) a najdi sekci
**⚙️ KONFIGURACE** hned na začátku `<script>` bloku (řádek ~315, hledej `const CONFIG`). Vyplň:

```js
const CONFIG = {
  SUPABASE_URL:      'https://abcdefghijkl.supabase.co',      // z kroku 1
  SUPABASE_ANON_KEY: 'eyJhbGciOi...',                          // z kroku 1
  GOOGLE_CLIENT_ID:  '1234567890-abc.apps.googleusercontent.com', // z kroku 2
  ACCESS_CODE:       'mistri2026',   // přístupový kód do appky — změň, pokud chceš
  MIN_PEOPLE_DEFAULT: 3,             // kolik lidí musí vyjít, aby se termín nabídl (výchozí filtr)
  HOUR_FROM: 6,                      // mřížka od 6:00
  HOUR_TO:   22,                     // mřížka do 22:00
  CANDIDATE_WEEKS: 26,               // jak daleko dopředu hledat termíny
  STUDIO_LOCATION: 'Studio — Praha', // co se propíše do pozvánky jako místo
  SHOW_NAME: 'Mistři světa'
};
```

Nic jiného v souboru měnit nemusíš. Ulož.

### Změna lidí v týmu

Seznam lidí je natvrdo na **dvou místech** — když chceš změnit jméno, e-mail nebo barvu, uprav obě:

- `supabase.sql` → sekce `insert into public.members` → pak SQL v Supabase pusť znovu
  (skript existující řádky přepíše, nic nesmaže)
- `index.html` → `MEMBERS_FALLBACK` → stejné řádky

Aktuálně: 4 moderátoři, **Studio** (zadává volné termíny studia) a **Honza Vosecký** jako
operátor streamu — ten se přidává **automaticky ke každé odeslané pozvánce**.

---

## 4. Nasazení na GitHub Pages

1. Na [github.com](https://github.com) → **New repository**
   - *Name*: `mistri-planovac`
   - **Public** (GitHub Pages na free účtu funguje jen u veřejných repozitářů)
   - **Create repository**
2. Na stránce nového repozitáře klikni **uploading an existing file** a nahraj soubory
   `index.html`, `supabase.sql`, `README.md` → **Commit changes**.
3. **Settings** (v repozitáři) → vlevo **Pages**
   - *Source*: **Deploy from a branch**
   - *Branch*: **main** + složka **/ (root)** → **Save**
4. Počkej 1–2 minuty. Adresa bude:

   ```
   https://vildafranek.github.io/mistri-planovac/
   ```

Jakoukoliv další změnu uděláš tak, že soubor v GitHubu otevřeš, klikneš na tužku, upravíš a uložíš —
web se sám přegeneruje do minuty.

> Repozitář je veřejný, takže je v něm vidět i `anon` klíč a přístupový kód. Viz poznámka
> k bezpečnosti výš — pro tenhle typ dat je to v pořádku, ale počítej s tím.

---

## 5. Jak to poslat kolegům

Do WhatsAppu stačí jedna zpráva:

> Kluci, konec domlouvání v chatu 🙂
> **https://vildafranek.github.io/mistri-planovac/**
> Kód: **mistri2026**
> Vyberete se ze seznamu, naklikáte hodiny, kdy můžete (podržet a táhnout = víc hodin naráz),
> a appka sama vyhodí termíny, kdy nás vyjde nejvíc. Přidejte si to na plochu telefonu.

**Přidání na plochu telefonu** (vyplatí se, chová se to pak jako appka):
- iPhone / Safari: tlačítko *Sdílet* → *Přidat na plochu*
- Android / Chrome: menu ⋮ → *Přidat na plochu*

**Studio**: zástupci studia pošli stejný odkaz a řekni mu, ať si při výběru zvolí **Studio**.
Zadává jen hodiny, kdy je studio volné. Není to podmínka termínu — bere se to jako bonus.

**Operátor streamu (Honza Vosecký)**: stejný odkaz, při výběru se zvolí. Vidí celý kalendář,
zadává svoji dostupnost a může i potvrzovat termíny a rozesílat pozvánky. Do překryvu moderátorů
se nezapočítává — u termínu se jen ukáže odznak *🎬 operátor může*.

**Hosté**: hosta si založíš v záložce *Hosté*, appka vygeneruje odkaz typu `…/?guest=abc123`.
Ten pošli hostovi — uvidí jen jednoduchou stránku „Kdy se vám to hodí?“ a nic z vašeho plánování.

---

## Jak se to používá

**Dostupnost** — týdenní mřížka po hodinách, šipkami listuješ týdny libovolně dopředu.
- Klik na buňku = přepnout jednu hodinu
- Podržet prst a táhnout = vybrat víc hodin najednou (na počítači stačí táhnout myší)
- Klik na název dne (PO, ÚT…) = celý den
- Přepínač nahoře: *Můžu na dálku* / *Můžu i do studia* (studio automaticky znamená i call)
- Zkratky: *Zkopírovat minulý týden*, *Zkopírovat od…* (převezmeš výběr kolegy),
  *Opakovat každý týden* (např. každé úterý 9–12 až do zadaného data)
- Poloprůhledné tečky dole v buňce = ostatní, fialový pruh nahoře = volné studio
- Zelený čárkovaný rámeček = na tuhle hodinu už je domluvené natáčení

**Termíny** — hlavní výstup.
- Nahoře *Kandidáti na natáčení*, rozdělení do sekcí podle toho, kolik vás vyjde:
  **Můžou všichni (4)** nahoře, pak **Může 3 ze 4**, případně **2 ze 4**.
- Filtry: délka (60/90/120 min, výchozí 90) a *kolik nás musí minimálně být* (výchozí 3 a víc)
- U každého termínu je vidět, **kdo** může (barevné avatary, šedí ti, co nemůžou)
- Studio se neřeší dopředu — když zrovna vyjde, objeví se odznak **🎙 studio volné** jako bonus.
  Stejně tak **🎬 operátor může**.
- Klik na čas = potvrdit termín (může kdokoliv z vás). V dialogu upravíš, **kdo dorazí**,
  a vybereš, jestli to bude *online call* nebo *ve studiu*.
- Dole heatmapa: číslo v buňce = kolik moderátorů může

**Rezervace** — fronta *K odeslání* (potvrzené termíny bez pozvánky) a seznam *Zarezervováno*.
- *Odeslat pozvánku* → přihlásíš se Googlem, vytvoří se událost v **tvém** kalendáři
  s hosty → všem přijde pozvánka do mailu. Pozvánka jde **jen označeným účastníkům**
  + operátorovi streamu (má-li vyplněný e-mail) + hostovi u hostovského dílu.
- *Stáhnout .ics* → záložní varianta, když Google není nastavený
- *Počet dílů* u termínu — jedno 90min natáčení může pokrýt víc dílů, propíše se do pozvánky
- *Zrušit* → termín přejde do stavu zrušeno (událost v Google Kalendáři je pak nutné smazat ručně)

**Hosté** — založíš hosta, pošleš mu odkaz, on navrhne možnosti.
U každé možnosti pak klikáte *Dorazím* / *Nemůžu*, u každé je vidět kolik vás může a jestli sedí
studio. Nakonec kdokoliv klikne *Vybrat tento termín* → dál je to stejné jako u běžného termínu.

**Stavy termínu**: kandidát (jen návrh, není v databázi) → potvrzeno → zarezervováno (+ zrušeno).
U každého je vidět, kdo a kdy ho potvrdil a rezervoval.

---

## Časová zóna

Všechno se ukládá jako **datum + hodina** (žádný timestamp), takže nikde nevzniká posun.
Do Google Kalendáře i do `.ics` se čas převádí na `Europe/Prague` včetně letního/zimního času.

---

## Když něco nefunguje

| problém | řešení |
|---|---|
| „Ukázkový režim“ v oranžovém rámečku | Nejsou vyplněné `SUPABASE_URL` / `SUPABASE_ANON_KEY`. Viz krok 3. |
| Nic se neukládá / hláška „Uložení selhalo“ | Neproběhl `supabase.sql`, nebo je špatně URL/klíč. Pusť SQL znovu. |
| Přihlášení Googlem hodí chybu o origin | V Google Console chybí `https://vildafranek.github.io` v *Authorized JavaScript origins*. Bez lomítka na konci. |
| „Google hasn't verified this app“ | Normální u neověřené interní appky: *Advanced* → *Go to Mistři světa (unsafe)*. Nebo přidej člověka do *Test users*. |
| Pozvánka nedorazila | Zkontroluj spam. Událost vzniká v kalendáři toho, kdo klikl na *Odeslat pozvánku* — musí být přihlášený Googlem. |
| Termín nejde potvrdit („už existuje“) | Na stejné datum a čas už jeden aktivní termín je. Najdeš ho v *Rezervace*. |
| Chci vymazat všechna testovací data | V Supabase → *SQL Editor*: `truncate availability, week_status, sessions, guest_rsvps, guest_options, guests;` |

---

## Ceny

Supabase Free tier: 500 MB databáze, 5 GB přenosů měsíčně. Tahle appka se vejde do jednotek MB
i po letech provozu. GitHub Pages i Google Calendar API jsou zdarma.

Jediný háček Free tieru: projekt, do kterého se **týden nikdo nepřipojí**, Supabase uspí
(probudí se sám při dalším otevření, jen to chvilku trvá). Když do appky občas kouknete, nestane se to.
