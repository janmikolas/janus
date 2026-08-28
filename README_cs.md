# Janus

Janus je workspace pro tvorbu AI agentů, jejich propojení s externími službami
přes MCP a porovnávání nebo slučování jejich odpovědí v jednom chatu.

Uživatel si může připojit služby, sestavit nad nimi agenty s vlastní identitou a
instrukcemi a potom zvolit, zda chce odpověď jednoho agenta, několik nezávislých
odpovědí vedle sebe, nebo společnou syntézu.

> [!IMPORTANT]
> Janus je v rané fázi vývoje a není připravený pro produkční použití. Frontend
> obsahuje hotový persistentní tok pro registraci, přihlášení, správu agentů a
> CRUD chatů nad skutečným backendovým API. Režimy SINGLE a PARALLEL vytvářejí
> samostatné Agent Runs, spouštějí je přes lokální Service Bus Emulator a
> hostitelský Codex app-server a streamují jejich stav přes SSE. Statické MCP
> servery Košík a Rohlík lze pro každý Agent Run explicitně povolit, ale
> uživatelské Connections, auditní persistence Tool Calls a Synthesis Run zatím
> hotové nejsou.

## Co Janus řeší

Běžná AI aplikace zpravidla skryje výběr zdrojů i průběh práce do jedné odpovědi.
Janus zachovává rozdíl mezi zdrojem nástrojů, agentem, jednotlivým spuštěním a
případnou následnou syntézou. Díky tomu má být možné:

- připojit externí služby a řídit, kteří agenti je mohou používat;
- vytvořit specializovaného agenta nad jedním i více MCP propojeními;
- položit stejnou otázku více agentům a porovnat jejich odpovědi vedle sebe;
- oslovit jen vybrané účastníky existujícího skupinového chatu;
- sloučit dohledatelné dílčí výsledky do samostatného doporučení;
- průběžně zobrazovat hotové výsledky, i když jiné běhy ještě pracují nebo
  selhaly;
- dohledat, který agent a tool vytvořil konkrétní výsledek.

## Jak fungují základní pojmy

| Pojem | Význam |
| --- | --- |
| **Workspace / User** | Vlastník agentů, propojení, chatů a execution dat. |
| **Connection** | Napojení na externí službu nebo sadu tools, například MCP Košík, Gmail nebo Calendar. |
| **Agent** | AI identita s vlastními instrukcemi, modelem a přístupem k jedné či více Connections. |
| **Agent Group** | Množina agentů dostupných jako účastníci společného chatu. |
| **Chat / Message** | Konverzace a konkrétní zpráva adresovaná vybraným agentům. |
| **Agent Run** | Samostatně sledované spuštění jednoho agenta pro konkrétní zprávu. |
| **Tool Call** | Konkrétní volání externího nástroje v rámci jednoho Agent Run. |

### Connection není Agent

Connection pouze zpřístupňuje externí tools. Agent nad nimi přidává vlastní
identitu, instrukce, rozhodování a výslednou odpověď. Jeden agent proto může
používat více propojení:

```text
Agent Potraviny
├── MCP Košík
└── MCP Rohlík

prompt -> oba zdroje -> agentova syntéza -> jedna odpověď
```

To je jiný scénář než dva samostatní agenti:

```text
                 user prompt
                    │
           ┌────────┴────────┐
           ▼                 ▼
      Agent Košík       Agent Rohlík
           │                 │
      MCP Košík         MCP Rohlík
           │                 │
           ▼                 ▼
      odpověď A         odpověď B
```

Druhý scénář zachovává odpovědi oddělené a umožňuje jejich přímé porovnání.

## Režimy odpovědi

### Single

Zprávu dostane jeden vybraný agent. Ten podle situace použije pouze potřebné
tools ze svých povolených Connections.

### Independent / Parallel

Stejnou zprávu dostane více agentů. Každý má vlastní Agent Run, tools, průběh,
výsledek a error state. Selhání jednoho agenta nezahodí úspěšnou odpověď jiného.

```text
Košík                  Rohlík
✓ completed            ✕ failed
odpověď A              samostatná chyba
```

### Synthesis

Nejprve vzniknou samostatné dílčí výsledky. Následný LLM krok je sloučí do
společného výstupu, aniž by původní odpovědi přepsal.

```text
Košík response ───┐
                  ├── Synthesis LLM ──► společné doporučení
Rohlík response ──┘
```

## Zamýšlený uživatelský tok

1. Uživatel připojí externí služby v sekci **Propojení**.
2. Vytvoří agenta, nastaví jeho identitu a instrukce a povolí mu konkrétní
   Connections.
3. Založí chat nebo skupinu a vybere dostupné účastníky.
4. U konkrétní zprávy zvolí recipienty a režim Single, Parallel nebo Synthesis.
5. Janus zobrazí průběh a výsledky jednotlivých Agent Runs postupně.
6. Uživatel může porovnat zdrojové odpovědi, samostatné chyby i případnou syntézu.

## Stav repozitáře

Repozitář skládá frontend a backend jako samostatné Git submodules:

```text
janus/
├── AGENTS.md          # společná technická a pracovní pravidla
├── Makefile           # společné příkazy delegované do submodules
├── README.md          # produktový směr a veřejná orientace
├── backend/           # současný infrastrukturní backendový základ
└── frontend/          # Vue prototyp uživatelského rozhraní
```

### Frontend

Frontend používá Vue 3, TypeScript, Vite, Tailwind CSS, Vue Router, Pinia,
TanStack Vue Query a Vitest. Aktuálně obsahuje obrazovky pro:

- persistentní chaty a historii uživatelských zpráv;
- výběr aktuálně spustitelných režimů Single a Parallel;
- správu agentů a jejich povolených Connections;
- správu MCP propojení.

Správa agentů, přihlášení, registrace, ochrana rout i chatové CRUD operace a
ukládání user messages komunikují se skutečným backendovým API. Frontend
zobrazuje nezávislé Agent Runs, jejich průběžný text a souběžné success/failure
stavy ze SSE. SYNTHESIZE se v UI nenabízí, dokud nevznikne samostatný
Synthesis Run. Obrazovka Connections je stále lokální prezentační základ.
Podrobnosti a příkazy jsou ve [`frontend/README.md`](frontend/README.md).

### Backend

Backend používá Kotlin, Quarkus, JDK/JVM 25 a Gradle. Je připravený jako
jednoduchý modulární monolit a obsahuje PostgreSQL s Flyway, MongoDB, Redis, OpenAPI,
health checks a OpenTelemetry. Obsahuje modul `identity` s lokální registrací a
Quarkus Security autentizací a modul `agent` pro vlastněnou, PostgreSQL
persistovanou správu agentů a jejich connector kódů. Modul `chat` přidává CRUD
vlastních chatů a historii uživatelských zpráv s execution mode a relačním
výběrem Agent IDs. Pro SINGLE a PARALLEL ve stejné transakci vytváří Agent Runs
a outbox eventy, asynchronně je předává lokálním Service Busem do Codex
app-serveru a ukládá jejich nezávislé průběhy, výsledky a chyby. Pro každý run
vytvoří fail-closed MCP allow-list z connector kódů `KOSIK` a `ROHLIK`; všechny
ostatní MCP servery a Codex Apps zůstávají vypnuté. První run konkrétního Agenta
v Chatu založí trvalý Codex thread a další zprávy stejné dvojice `Chat + Agent`
jej obnoví, takže si Agent drží kontext daného chatu. Service Bus session přitom
zachovává pořadí těchto runů bez blokování jiných Agents. SYNTHESIZE backend
explicitně odmítne.
Redis drží distribuované API rate limits a obnovované leases současných SSE
spojení; pseudonymizovaný audit těchto rozhodnutí se ukládá s omezenou retencí
do MongoDB.

Dokumentace současného bootstrapu je v
[`backend/README.md`](backend/README.md). Architektonická pravidla a popis tohoto
přechodného stavu jsou v [`AGENTS.md`](AGENTS.md).

## Spuštění a ověření

Po naklonování inicializujte submodules:

```sh
git submodule update --init --recursive
```

Root Makefile deleguje společné workflow do backendového a frontendového
Makefilu. Pro tento workflow stačí Make a Docker; Java, Gradle, Node ani npm
nemusí být nainstalované na hostu:

```sh
make help
make up-build
make ps
make test
make check
make build
make down
```

Jednu část lze oslovit prefixem, například `make backend-integration-test`,
`make backend-format`, `make frontend-test-watch` nebo obecně
`make backend-<target>` / `make frontend-<target>`.

Přímé npm, Gradle a Compose příkazy zůstávají dostupné. Pro lokální frontend
bez Dockeru je potřeba Node.js 24 nebo kompatibilní novější verze:

```sh
cd frontend
npm ci
npm run dev
```

Výchozí adresa je <http://localhost:5173>.

Frontend lze spustit také v Dockeru:

```sh
cd frontend
docker compose up --build
```

Ověření současného frontendu:

```sh
cd frontend
npm run lint
npm test
npm run build
```

## Technický směr

Projekt bude růst po malých end-to-end use-casech. Hlavní principy jsou:

- jednoduché a explicitní řešení před obecnými frameworky;
- modulární monolit před předčasnými microservices;
- jasné hranice mezi doménou, API, persistence, LLM a MCP integracemi;
- samostatně auditovatelné Agent Runs a Tool Calls;
- partial results místo all-or-nothing multi-agent odpovědi;
- server-side authorization a izolace dat mezi workspaces/users;
- credentials pouze na bezpečné backendové boundary;
- ověřený Tool Call jako důkaz externí akce, nikdy samotné tvrzení LLM;
- testovatelnost od první skutečné feature.

První malé vertikální flows tvoří registrace a přihlášení, správa agentů,
persistence chatů a asynchronní SINGLE/PARALLEL Agent Runs se staticky
allowlistovanými MCP servery Košík/Rohlík. Další backendové milníky mají stejným
způsobem přidávat uživatelské Connections, auditní Tool Calls a samostatný
Synthesis Run, nikoli obecný orchestration framework.

## Vývoj a přispívání

Před změnou si přečtěte root [`AGENTS.md`](AGENTS.md) a potom také odpovídající
`backend/AGENTS.md` nebo `frontend/AGENTS.md`. Tyto dokumenty obsahují skutečné
příkazy, lokální konvence, bezpečnostní invarianty a Definition of Done.

Pokud změna ovlivní API, data nebo realtime stavy, zkontrolujte vždy backend i
frontend. Do repozitáře nepatří secrets, credentials, lokální `.env` hodnoty ani
generované build výstupy.
