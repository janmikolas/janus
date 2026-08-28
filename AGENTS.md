# Janus — pravidla pro coding agenty

Tento dokument je společná produktová a pracovní ústava repozitáře. Platí pro
root, `backend/` i `frontend/`. Janus je **multi-agent AI workspace**: umožňuje
uživatelům vytvářet agenty napojené na externí nástroje, oslovovat jednoho nebo
více agentů v chatu a uchovávat samostatné, dohledatelné výsledky jejich běhů.

Před změnou vždy přečti také nejbližší vnořený dokument:

- [`backend/AGENTS.md`](backend/AGENTS.md) vlastní backendovou implementaci,
  architekturu, infrastrukturu a validační příkazy;
- [`frontend/AGENTS.md`](frontend/AGENTS.md) vlastní frontendovou strukturu,
  konvence a validační příkazy.

Vnořený dokument doplňuje tato pravidla, ale nesmí měnit níže uvedený produktový
význam ani bezpečnostní invarianty. Root `AGENTS.md` nemá určovat databázová
schémata, API transport, frameworkové vrstvy ani jiné implementační detaily.

## Zdroje pravdy

- Root [`README.md`](README.md) je veřejná produktová a onboardingová orientace.
- Tento soubor určuje terminologii, produktové chování, execution semantics a
  repository-wide zásady pro změny.
- Skutečný stav dokazují kód, testy, manifesty a konfigurace. Nevydávej plánovanou
  entitu, integraci nebo workflow za existující, dokud v repozitáři opravdu není.
- Pokud se dokumentace rozchází s implementací, rozpor nejprve ověř a pojmenuj.
  Neměň produktové chování jen proto, aby odpovídalo zastaralému textu.

## Co Janus staví

Uživatel může:

- vytvořit externí **Connections**, primárně integrace založené na MCP;
- vytvořit **Agents** s vlastním názvem, instrukcemi, konfigurací modelu a jednou
  nebo více Connections;
- vytvořit **Groups** obsahující více Agents;
- vytvořit více **Chats** uvnitř jedné Group;
- pro každou jednotlivou uživatelskou zprávu explicitně vybrat, kteří Agents ji
  dostanou;
- zachovat historii chatu, jednotlivé Agent Runs, jejich samostatné výsledky a
  případnou následnou syntézu.

Základní vztahy lze číst takto:

```text
User
├── Connections
├── Agents ── používají jednu nebo více Connections
└── Groups
    ├── obsahují více Agents
    └── obsahují více Chats
        └── Message / Turn
            ├── explicitně vybraní recipienti
            ├── jeden nebo více Agent Runs
            └── volitelný Synthesis Run
```

## Terminologie

| Pojem | Produktový význam |
| --- | --- |
| **User** | Vlastník svých Connections, Agents, Groups, Chats a execution historie. |
| **Connection** | Napojení na externí službu nebo sadu tools, primárně přes MCP. Connection sama nevytváří agentovu odpověď. |
| **Agent** | AI identita s vlastním názvem, instrukcemi, konfigurací modelu a povolenou sadou Connections. Vytváří vlastní odpověď. |
| **Group** | Množina Agents dostupných jako účastníci jejích Chats. Členství samo neznamená, že Agent dostane každou zprávu. |
| **Chat** | Samostatná konverzace uvnitř Group. Jedna Group může mít více Chats. |
| **Message / Turn** | Jednotlivý uživatelský prompt v Chatu spolu s execution režimem a explicitně vybranými recipienty. |
| **Agent Run** | Samostatně sledované spuštění jednoho Agenta pro konkrétní Message. Má vlastní průběh, tool calls, výsledek nebo chybu. |
| **Tool Call** | Konkrétní volání nástroje přes konkrétní Connection v rámci jednoho Agent Run. |
| **Synthesis Run** | Samostatný následný LLM krok, který z dohledatelných výstupů více Agent Runs vytvoří kombinovanou odpověď. |

Názvy zobrazené uživateli nejsou identita. Historie musí být svázána se
stabilními identifikátory a původem výsledků.

## Zásadní doménové rozdíly

### Connection není Agent

Connection zpřístupňuje externí službu nebo tools. Agent přidává vlastní
instrukce, modelové rozhodování a finální odpověď. Jeden Agent může během jednoho
runu použít více svých Connections/MCP tools a informace z nich sloučit do jedné
vlastní odpovědi.

To je interní práce jednoho Agenta, nikoli režim SYNTHESIZE. Tool output také
není automaticky finální odpověď Agenta.

### Group není seznam automatických recipientů

Group vymezuje dostupné účastníky, ale recipienti se volí pro každou Message
zvlášť. Dvě zprávy ve stejném Chatu tak mohou spustit různé podmnožiny Agents.
Změna členství Group nesmí zpětně změnit recipienty ani původ starších výsledků.

### Message není Agent Run

Jedna Message může založit jeden nebo více Agent Runs. Každý run má vlastní
identitu, lifecycle, tools, výsledek a error/cancellation stav. Pořadí dokončení
runů neurčuje jejich identitu ani pořadí v historii.

## Execution režimy

Rozdíl mezi režimy je podstata Janusu:

```text
SINGLE      1 agent  → případně N MCP          → 1 odpověď
PARALLEL    N agentů → každý nezávisle         → N odpovědí
SYNTHESIZE  N agentů → N nezávislých odpovědí → další LLM → 1 syntéza
```

Režim a recipienti patří ke konkrétní Message/Turn a musí zůstat součástí její
historie.

### SINGLE

Prompt dostane právě jeden vybraný Agent. Vznikne jeden Agent Run. Agent může
interně použít jeden nebo více potřebných MCP tools ze svých nakonfigurovaných
Connections a vytvoří jednu finální odpověď. Přítomnost více Connections
neznamená, že musí zavolat všechny.

```text
User prompt
→ Agent "Potraviny"
→ Košík MCP + Rohlík MCP
→ one Agent response
```

Sloučení informací z více Connections uvnitř tohoto Agenta je stále SINGLE.

### PARALLEL

Stejný prompt dostane více vybraných Agents. Pro každého vznikne nezávislý Agent
Run s jeho vlastními instrukcemi, konfigurací modelu, Connections, tool calls,
výsledkem a chybami. Odpovědi zůstávají samostatné.

```text
User prompt
├→ Košík Agent → Košík MCP → Response A
└→ Rohlík Agent → Rohlík MCP → Response B
```

Agents mohou dokončit v libovolném pořadí. Dokončená odpověď musí být dostupná
ihned bez čekání na pomalejší běhy. Selhání nebo zrušení jednoho runu nesmí
znehodnotit úspěšné výsledky ostatních; partial success je platný výsledek.

### SYNTHESIZE

Nejprve proběhne více nezávislých Agent Runs stejně jako v režimu PARALLEL a
vzniknou jejich samostatné odpovědi. Teprve potom samostatný Synthesis Run/model
dostane dohledatelné dokončené výstupy a vytvoří kombinované doporučení nebo
odpověď.

```text
User prompt
├→ Agent A → Response A ─┐
└→ Agent B → Response B ─┴→ Synthesis → Combined response
```

Původní Agent responses musí zůstat dostupné a syntéza je nesmí přepsat ani se
vydávat za odpověď některého zdrojového Agenta. Synthesis Run má vlastní stav,
model, výsledek nebo chybu a dohledatelné vstupní Agent Runs. Jeho selhání nesmí
odstranit úspěšné zdrojové odpovědi.

## Repository-wide produktové invarianty

- Vlastnictví a oprávnění se ověřují při každém čtení i zápisu. Znalost ID není
  oprávnění a UI omezení není security boundary.
- Agent smí používat pouze Connections/tools, ke kterým má oprávnění v kontextu
  daného Usera.
- Chat history zachovává původní zprávu, režim, recipienty, jednotlivé Agent Runs,
  Tool Calls, chyby, výsledky a případný Synthesis Run.
- Samostatné runy nesmějí být skryty za jedním all-or-nothing stavem. Loading,
  completed, failed a cancelled výsledky musí být reprezentovatelné současně.
- Každý Tool Call musí být dohledatelný ke konkrétnímu Agent Run a Connection.
  Retry je nový dohledatelný pokus, ne přepsání předchozí historie.
- LLM text není důkaz, že externí akce proběhla. Úspěch lze tvrdit jen podle
  ověřené odpovědi příslušného Tool Callu/integrace.
- Credentials a secrets se neposílají do frontendu, neukládají do auditní
  historie a nelogují. Externí vstupy, MCP/tool output i LLM output jsou
  nedůvěryhodná data.
- Provider, konkrétní model, MCP/LLM SDK, databáze a transport jsou vyměnitelné
  implementační volby. Nesmějí měnit zde definovaný produktový význam.

## Repository-wide vývojové zásady

- Začni nejmenším end-to-end use-casem, který ověří skutečnou potřebu.
- Preferuj řešení `simple`, `explicit`, `testable`, `replaceable`. Nevytvářej
  předem obecný agentní framework, orchestration DSL ani infrastrukturu pro
  hypotetické požadavky.
- Dodrž existující pattern feature a neprováděj nesouvisející refactoring,
  dependency churn nebo spekulativní rozšiřování scope.
- Business invarianty, authorization a bezpečnostní rozhodnutí nesmějí existovat
  pouze ve frontendu.
- Změnu sdíleného kontraktu kontroluj na straně producenta i konzumenta, včetně
  loading, partial-success, failure, retry a cancellation stavů.
- Testuj podle rizika. U execution flow pokrývej zejména nezávislost runů,
  dokončení mimo pořadí, partial failure, tool failure/retry a zachování
  zdrojových odpovědí při syntéze.
- Externí LLM/MCP systémy drž za testovatelnou hranicí; běžné automatické testy
  musí být deterministické.

## Pracovní postup

1. Přečti tento dokument a relevantní vnořený `AGENTS.md`.
2. Prozkoumej související kód, testy, manifesty, konfiguraci a dokumentaci.
3. Ověř dopad na produktové pojmy, execution režimy, historii, provenance,
   authorization, frontend/backend kontrakt a partial-failure stavy.
4. Implementuj nejmenší konzistentní změnu bez nesouvisejícího refactoringu.
5. Přidej nebo uprav relevantní testy a spusť skutečně existující kontroly
   popsané ve vnořeném `AGENTS.md` a manifestech.
6. Zkontroluj celý diff, včetně změn kontraktu, konfigurace a dokumentace.

Root `Makefile` je tenký orchestration wrapper nad skutečnými příkazy v
`backend/Makefile` a `frontend/Makefile`. Nabízí `make up`, `make up-build`,
`make down`, `make ps`, `make test`, `make integration-test`, `make check`,
`make build`, `make images` a backendové `make format`. Cílený příkaz lze
delegovat jako `make backend-<target>` nebo `make frontend-<target>`; dostupné
targety vypíše `make help` a odpovídající vnořený `make help`.

Make targety musí zůstat jednoduché aliasy existujícího Gradle, npm a Docker
Compose workflow. Výchozí targety běží v projektových Docker images, takže
root workflow vyžaduje Make a Docker, ne hostitelské JDK nebo Node.js.
`backend integration-test` navíc jednorázově připojuje Docker socket pro
Testcontainers; tento přístup nerozšiřuj do běžného dev kontejneru.

Skutečné chování a detailní validační příkazy nadále vlastní vnořené
manifesty, README a `AGENTS.md`. Při cross-stack změně spusť relevantní
kontroly v obou částech a transparentně uveď každý nedostupný, přeskočený
nebo selhávající check.

## Definition of Done

- Změna zachovává terminologii a sémantiku režimů SINGLE, PARALLEL a SYNTHESIZE.
- Samostatné Agent Runs, Tool Calls, chyby, partial results a provenance zůstávají
  dohledatelné.
- Frontend/backend kontrakt je konzistentní a authorization není pouze v UI.
- Relevantní testy a existující statické/build kontroly procházejí.
- Změna nepřidává secrets, nesouvisející refactoring ani spekulativní abstrakce.
- Dokumentace popisuje skutečný stav; implementační detaily zůstávají v
  odpovídajícím vnořeném `AGENTS.md`.
