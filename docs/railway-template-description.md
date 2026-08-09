# Deploy and Host GBrain on Railway

Your AI agent forgets everything the moment the conversation ends. GBrain is the memory it has been missing. It is a knowledge base your agent can search, write to and reason over, living at a URL any MCP client can reach.

## About Hosting GBrain

Most search tools hand back a list of pages and leave the reading to you. GBrain reads them and writes the answer, with citations, and it tells you what it doesn't know yet. Every page it stores is wired into a knowledge graph as you go. So a question like "what did we decide about pricing, and who was in the room?" has somewhere to land.

[GBrain](https://github.com/garrytan/gbrain) was built by Garry Tan to run his own agents. It is designed to run on your infrastructure: your database, your keys, your notes. This template is the shortest path to that. One Railway service with the database built in. No second service to deploy, no connection string to wire up, and nothing that phones home.

Pick an embedding model, add your key for it, and your agent has a memory.

## Common Use Cases

- **Give your coding agent real memory.** Claude Code, Cursor, Windsurf and Codex can recall architecture decisions, past debugging sessions and project context instead of starting cold every session.
- **Keep a personal brain that answers back.** Capture notes, meetings and half-formed ideas from any device. Ask a question and get a written answer with sources.
- **Share what your team knows.** Point everyone's agents at one brain, with scoped access so each client reaches only what it should.

## Dependencies for GBrain Hosting

- **An embedding API key.** OpenAI, ZeroEntropy, Voyage or Google. This is the only value you provide. The service will not start without one, because a brain built against the wrong provider breaks in confusing ways later.

### Deployment Dependencies

- [GBrain](https://github.com/garrytan/gbrain), the knowledge brain and MCP server
- [Model Context Protocol](https://modelcontextprotocol.io), how AI clients talk to it
- [Railway Volumes](https://docs.railway.com/volumes), where the brain lives

### Implementation Details

Setup is three steps.

**1. Deploy.** Paste your embedding API key into the one required field and click deploy. The volume and the public domain come with the template, so there is nothing to attach or generate.

**2. Connect your agent.** Copy the token printed in your Deploy Logs, then point your agent at the service. Claude Code is one line:

```bash
claude mcp add --transport http gbrain https://your-app.up.railway.app/mcp \
  --header "Authorization: Bearer gbrain_xxx"
```

Cursor, Windsurf and Codex take a few lines of config. Claude Desktop, Claude Cowork, ChatGPT and Perplexity connect through their own settings screens. The repo has the exact steps for each.

**3. Open the dashboard.** Go to `/admin` and log in with the admin token Railway generated for you. Register clients, watch live activity, read request logs.

What you get out of the box:

- **A brain over MCP.** 30+ tools at `/mcp`, with OAuth 2.1 and scoped access
- **No database to run.** PGLite (Postgres compiled to WebAssembly) rides along inside the service
- **Answers, not just results.** Hybrid search across vectors, keywords and a self-building knowledge graph
- **An admin dashboard.** Live activity, connected clients and request logs
- **Storage that survives.** Brain, config and tokens persist across redeploys, with Railway backups a click away
- **A pinned release.** The image ships a known-good GBrain version, so redeploying never changes behavior underneath you

Comfortable at the scale of a personal or small-team brain, roughly tens of thousands of pages. Beyond that, point it at Postgres with pgvector instead. The repo documents how.

## Why Deploy GBrain on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GBrain on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

---

<sub>A community-maintained deployment template, not affiliated with or officially supported by the GBrain project. GBrain is built by Garry Tan and licensed MIT. All trademarks belong to their respective owners.</sub>
