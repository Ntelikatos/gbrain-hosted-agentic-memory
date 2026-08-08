# Deploy and Host GBrain on Railway

GBrain is a Postgres-native knowledge brain that gives AI agents real memory — hybrid search, a self-wiring knowledge graph, and a synthesis layer that returns cited answers instead of a list of pages. Deploy it on Railway and connect Claude Code, Codex, Cursor, or ChatGPT to a brain that remembers everything your agent has ever been told.

## About Hosting GBrain

Coding agents are amnesiac about everything that isn't code. They re-learn your architecture decisions every session, forget what you told them yesterday, and have no idea what was said in last week's meeting. GBrain fixes that by giving your agent a persistent brain it can search, write to, and traverse — exposed over MCP so any client can reach it.

Running it on Railway makes that brain always-on and reachable from every device, instead of tied to a laptop that has to stay awake. This template packages GBrain's HTTP MCP server with an embedded PGLite database, so there is no second service to deploy and no connection string to wire up. The volume, the public domain, and the admin token are all provisioned for you. Add your embedding API key, and a bearer token plus the exact connect command are printed in your deploy logs. One copy-paste and your agent has a memory.

## Common Use Cases

- **Give your coding agent a memory** — Connect Claude Code or Codex over MCP so it recalls architecture decisions, past debugging sessions, and project context instead of starting cold every time.
- **A personal knowledge brain that answers** — Capture notes, meetings, and ideas from any device, then ask questions and get a synthesized, cited answer with an honest note on what the brain doesn't know yet.
- **Shared institutional memory** — Point a whole team's agents at one brain, with scope-gated OAuth clients so each client only reaches what it should.

## Dependencies for GBrain Hosting

- **An embedding provider API key** — OpenAI, ZeroEntropy, or Voyage. Required, and the only value you supply; the brain's vector dimension is fixed at creation time, so the container refuses to start without one.

The volume (mounted at `/data`, holding the brain database, config, and tokens) and the public domain (which GBrain advertises as its OAuth issuer) are both provisioned by this template.

### Deployment Dependencies

- [GBrain](https://github.com/garrytan/gbrain) — the knowledge brain and MCP server
- [Railway Volumes](https://docs.railway.com/reference/volumes) — persistent storage for the brain
- [Model Context Protocol](https://modelcontextprotocol.io) — the transport AI clients use to reach it

### Implementation Details

Connect any MCP client to your hosted brain:

```bash
gbrain connect https://your-app.up.railway.app/mcp \
    --token gbrain_xxx --install
```

**What's included out of the box:**

- **HTTP MCP server** — 30+ operations at `/mcp` with OAuth 2.1 and scoped access
- **Embedded PGLite database** — Postgres 17 via WASM, no separate database service
- **Auto-provisioned access** — a bearer token minted on first boot, printed once with a ready-to-paste connect command
- **Admin dashboard** — live activity, registered clients, and request logs at `/admin`
- **Hybrid search** — vector plus BM25 keyword plus reciprocal-rank fusion, with a knowledge graph layered on top
- **Persistent brain** — database, config, and tokens survive redeploys via the Railway volume
- **Optional GitHub-backed brain repo** — keep your markdown system of record portable and readable locally
- **Pinned releases** — a known-good GBrain version is baked into the image, so redeploys are reproducible

## Why Deploy GBrain on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GBrain on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

---

<sub>This is a community-maintained deployment template. It is not affiliated with, endorsed by, or officially supported by the GBrain project. GBrain is built by Garry Tan and licensed MIT. All trademarks belong to their respective owners.</sub>
