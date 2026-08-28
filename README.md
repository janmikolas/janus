# Janus

Janus is a workspace for building AI agents, connecting them to external
services through MCP, and comparing or combining their answers in a single
chat.

Users can connect services, build agents with distinct identities and
instructions, and then choose whether they want an answer from one agent,
several independent answers side by side, or a combined synthesis.

> [!IMPORTANT]
> Janus is at an early stage of development and is not ready for production.
> The frontend provides working, persistent flows for registration, sign-in,
> agent management, and chat CRUD, all backed by the real backend API. SINGLE
> and PARALLEL create separate Agent Runs, dispatch them through the local
> Service Bus Emulator to a host Codex app-server, and stream their status over
> SSE. The static Košík and Rohlík MCP servers can be explicitly enabled for
> each Agent Run, but user-managed Connections, persistent Tool Call auditing,
> and a Synthesis Run have not been implemented yet.

## What Janus is designed to solve

Most AI applications hide both their choice of sources and their execution
process behind a single answer. Janus keeps tool sources, agents, individual
runs, and any subsequent synthesis distinct. This is intended to make it
possible to:

- connect external services and control which agents may use them;
- build a specialized agent on top of one or more MCP connections;
- ask several agents the same question and compare their answers side by side;
- address only selected participants in an existing group chat;
- combine traceable intermediate results into a separate recommendation;
- show completed results immediately, even while other runs are still working
  or have failed;
- trace a specific result back to the agent and tool that produced it.

## Core concepts

| Concept | Meaning |
| --- | --- |
| **Workspace / User** | The owner of agents, connections, chats, and execution data. |
| **Connection** | A link to an external service or set of tools, such as Košík MCP, Gmail, or Calendar. |
| **Agent** | An AI identity with its own instructions, model, and access to one or more Connections. |
| **Agent Group** | A set of agents available as participants in a shared chat. |
| **Chat / Message** | A conversation and a specific message addressed to selected agents. |
| **Agent Run** | An independently tracked execution of one agent for a specific message. |
| **Tool Call** | A specific call to an external tool within an Agent Run. |

### A Connection is not an Agent

A Connection only makes external tools available. An Agent adds its own
identity, instructions, decision-making, and final answer on top of those tools.
A single agent can therefore use more than one connection:

```text
Grocery Agent
├── Košík MCP
└── Rohlík MCP

prompt -> both sources -> agent combines results -> one answer
```

This is different from using two independent agents:

```text
                 user prompt
                    │
           ┌────────┴────────┐
           ▼                 ▼
       Košík Agent       Rohlík Agent
           │                 │
       Košík MCP         Rohlík MCP
           │                 │
           ▼                 ▼
       answer A          answer B
```

The second scenario keeps the answers separate so they can be compared
directly.

## Response modes

### Single

The message goes to one selected agent. The agent uses only the tools it needs
from its allowed Connections.

### Independent / Parallel

The same message goes to multiple agents. Each has its own Agent Run, tools,
progress, result, and error state. One agent's failure does not discard another
agent's successful answer.

```text
Košík                  Rohlík
✓ completed            ✕ failed
answer A               separate error
```

### Synthesis

The agents first produce separate source results. A subsequent LLM step combines
them into a shared output without overwriting the original answers.

```text
Košík response ───┐
                  ├── Synthesis LLM ──► combined recommendation
Rohlík response ──┘
```

## Intended user flow

1. The user connects external services under **Connections**.
2. They create an agent, define its identity and instructions, and grant it
   access to specific Connections.
3. They create a chat or group and choose the available participants.
4. For each message, they select the recipients and the Single, Parallel, or
   Synthesis mode.
5. Janus displays the progress and results of individual Agent Runs as they
   become available.
6. The user can compare the source answers, individual errors, and any resulting
   synthesis.

## Repository status

The repository brings the frontend and backend together as separate Git
submodules:

```text
janus/
├── AGENTS.md          # shared technical and development guidelines
├── Makefile           # shared commands delegated to the submodules
├── README.md          # product direction and public overview
├── backend/           # current backend and infrastructure foundation
└── frontend/          # Vue user-interface prototype
```

### Frontend

The frontend uses Vue 3, TypeScript, Vite, Tailwind CSS, Vue Router, Pinia,
TanStack Vue Query, and Vitest. It currently includes screens for:

- persistent chats and user-message history;
- selecting the currently supported Single and Parallel execution modes;
- managing agents and their allowed Connections;
- managing MCP connections.

Agent management, registration, sign-in, route protection, chat CRUD, and user
message persistence all communicate with the real backend API. The frontend
uses SSE to show independent Agent Runs, their streaming text, and concurrent
success and failure states. SYNTHESIZE is not offered in the UI until a separate
Synthesis Run is available. The Connections screen is still a local,
presentation-only view. See [`frontend/README.md`](frontend/README.md) for
details and commands.

### Backend

The backend uses Kotlin, Quarkus, JDK/JVM 25, and Gradle. It is structured as a
straightforward modular monolith and includes PostgreSQL with Flyway, MongoDB,
Redis, OpenAPI, health checks, and OpenTelemetry. Its `identity` module provides
local registration and authentication through Quarkus Security. The `agent`
module manages user-owned agents and their connector codes with PostgreSQL
persistence. The `chat` module adds CRUD for user-owned chats and a history of
user messages, including their execution mode and relationally stored selection
of Agent IDs.

For SINGLE and PARALLEL, the backend creates Agent Runs and outbox events in the
same transaction. It then dispatches them asynchronously through the local
Service Bus to the Codex app-server and stores each run's independent progress,
result, and errors. Each run receives a fail-closed MCP allowlist derived from
the `KOSIK` and `ROHLIK` connector codes; all other MCP servers and Codex Apps
remain disabled. The first run of a given Agent in a Chat creates a persistent
Codex thread. Later messages for the same `Chat + Agent` pair resume that thread,
allowing the Agent to retain context within the chat. A Service Bus session
preserves the order of those runs without blocking other Agents. The backend
explicitly rejects SYNTHESIZE.

Redis stores distributed API rate limits and renewable leases for active SSE
connections. A pseudonymized audit trail of those decisions is retained in
MongoDB for a limited period.

The current bootstrap is documented in
[`backend/README.md`](backend/README.md). Architectural guidelines and a
description of this transitional state are available in
[`AGENTS.md`](AGENTS.md).

## Running and validating the project

Initialize the submodules after cloning the repository:

```sh
git submodule update --init --recursive
```

The root Makefile delegates shared workflows to the backend and frontend
Makefiles. These workflows only require Make and Docker; Java, Gradle, Node.js,
and npm do not need to be installed on the host:

```sh
make help
make up-build
make ps
make test
make check
make build
make down
```

Prefix a target to address one part of the project—for example,
`make backend-integration-test`, `make backend-format`,
`make frontend-test-watch`, or more generally `make backend-<target>` and
`make frontend-<target>`.

The underlying npm, Gradle, and Compose commands remain available. Running the
frontend locally without Docker requires Node.js 24 or a compatible newer
release:

```sh
cd frontend
npm ci
npm run dev
```

The default address is <http://localhost:5173>.

You can also run the frontend in Docker:

```sh
cd frontend
docker compose up --build
```

To validate the current frontend:

```sh
cd frontend
npm run lint
npm test
npm run build
```

## Technical direction

The project will grow through small end-to-end use cases. Its guiding principles
are:

- simple, explicit solutions before general-purpose frameworks;
- a modular monolith before premature microservices;
- clear boundaries between the domain, API, persistence, LLM, and MCP
  integrations;
- independently auditable Agent Runs and Tool Calls;
- partial results instead of all-or-nothing multi-agent responses;
- server-side authorization and data isolation between workspaces and users;
- credentials kept exclusively behind a secure backend boundary;
- a verified Tool Call—not an LLM claim—as evidence that an external action
  occurred;
- testability from the first real feature onward.

The first small vertical flows cover registration and sign-in, agent management,
chat persistence, and asynchronous SINGLE/PARALLEL Agent Runs with statically
allowlisted Košík and Rohlík MCP servers. The next backend milestones will add
user-managed Connections, auditable Tool Calls, and a separate Synthesis Run in
the same incremental manner, rather than introducing a general orchestration
framework.

## Development and contributing

Before making changes, read the root [`AGENTS.md`](AGENTS.md), followed by the
relevant `backend/AGENTS.md` or `frontend/AGENTS.md`. These documents define the
actual commands, local conventions, security invariants, and Definition of Done.

If a change affects the API, data, or real-time states, always check both the
backend and frontend. Secrets, credentials, local `.env` values, and generated
build output do not belong in the repository.
