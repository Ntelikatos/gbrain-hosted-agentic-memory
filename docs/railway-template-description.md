# Deploy and Host GBrain on Railway

Your AI agent forgets everything the moment the conversation ends. GBrain is the memory it has been missing — a knowledge base your agent can search, write to, and reason over, living at a URL any MCP client can reach.

## About Hosting GBrain

Most search tools hand back a list of pages and leave the reading to you. GBrain reads them and writes the answer, with citations — and with an honest note about what it doesn't know yet. Every page it stores is wired into a knowledge graph as you go, so questions like "what did we decide about pricing, and who was in the room?" have somewhere to land.

[GBrain](https://github.com/garrytan/gbrain) was built by Garry Tan to run his own agents, and it is designed to run on your infrastructure: your database, your keys, your notes. This template is the shortest path to that. One Railway service with the database built in — no second service to deploy, no connection string to wire up, and nothing that phones home.

Pick an embedding model, add your key for it, and your deploy logs print the exact command to connect your agent. One copy-paste, and it remembers.

## Common Use Cases

- **Give your coding agent real memory** — Claude Code, Codex, or Cursor can recall architecture decisions, past debugging sessions, and project context instead of starting from nothing every session.
- **Keep a personal brain that answers back** — capture notes, meetings, and half-formed ideas from any device, then ask a question and get a written answer with sources, not a pile of search results.
- **Share what your team knows** — point everyone's agents at one brain, with scoped access so each client reaches only what it should.

## Dependencies for GBrain Hosting

- **An embedding API key** — OpenAI, ZeroEntropy, or Voyage. This is the only value you provide. The service will not start without one, because a brain built against the wrong provider breaks in confusing ways later.

### Deployment Dependencies

- [GBrain](https://github.com/garrytan/gbrain) — the knowledge brain and MCP server
- [Model Context Protocol](https://modelcontextprotocol.io) — how AI clients talk to it
- [Railway Volumes](https://docs.railway.com/volumes) — where the brain lives

### Implementation Details

Connect any MCP client once the service is up:

```bash
gbrain connect https://your-app.up.railway.app/mcp \
    --token gbrain_xxx --install
```

What you get out of the box:

- **A brain over MCP** — 30+ tools at `/mcp`, with OAuth 2.1 and scoped access
- **No database to run** — PGLite (Postgres compiled to WebAssembly) rides along inside the service
- **Answers, not just results** — hybrid search across vectors, keywords, and a self-building knowledge graph
- **An admin dashboard** — live activity, connected clients, and request logs at `/admin`
- **Storage that survives** — the brain, its config, and its tokens persist across redeploys, with Railway backups a click away
- **A pinned release** — the image ships a known-good GBrain version, so redeploying never changes behavior underneath you

Comfortable at the scale of a personal or small-team brain — roughly tens of thousands of pages. Beyond that, point it at Postgres with pgvector instead; the repo documents how.

## Why Deploy GBrain on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GBrain on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

---

<sub>A community-maintained deployment template, not affiliated with or officially supported by the GBrain project. GBrain is built by Garry Tan and licensed MIT. All trademarks belong to their respective owners.</sub>
