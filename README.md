# GBrain Hosted Agentic Memory

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/SQ3-sz?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)

[![Docker Build](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/docker-build.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/docker-build.yml)
[![Lint Dockerfile](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/lint-dockerfile.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/lint-dockerfile.yml)
[![ShellCheck](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/shellcheck.yml)
[![Trivy Security Scan](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/trivy.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/trivy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Your AI agent forgets everything when the chat ends. This template gives it a memory that doesn't. Deploy [GBrain](https://github.com/garrytan/gbrain) on Railway, paste one line into your agent, and it can remember.

## What You Get

- **A brain your agent can reach.** 30+ MCP tools at `https://your-app.up.railway.app/mcp`.
- **No database to run.** PGLite (Postgres compiled to WebAssembly) rides along inside the container.
- **Answers with sources.** `think` writes a cited answer and says what the brain still doesn't know.
- **A graph that builds itself.** Every page write extracts entities and links them. No LLM calls.
- **Storage that survives deploys.** Brain, config and tokens live on a Railway volume.
- **An admin dashboard.** Live activity, connected clients and request logs at `/admin`.

---

## Setup

The full guide lives on the Railway template page, with a section for every
supported agent:

**<https://railway.com/deploy/SQ3-sz>**

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/SQ3-sz?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)

In short: deploy the template with your embedding API key, copy the token
printed in the deploy logs, then point your agent at
`https://your-app.up.railway.app/mcp` using that token as a bearer header.
Claude Code, Cursor, Windsurf, Codex, Claude Desktop, Claude Cowork, ChatGPT
and Perplexity each have their own steps on that page, along with how to reach
the `/admin` dashboard.

That page is written in [docs/railway-template-description.md](docs/railway-template-description.md).
Edit it there, then paste it into the Railway template composer.

The rest of this file is reference material for running and modifying the
template.

---

## Environment Variables

| Variable | Required | Default | What it does |
| -------- | -------- | ------- | ------------ |
| `EMBEDDING_MODEL` | Yes* | auto | `<provider>:<model>`. Optional if you set a provider key directly. |
| `EMBEDDING_API_KEY` | Yes* | none | Key for the provider in `EMBEDDING_MODEL`. |
| `OPENAI_API_KEY` | No | none | Shorthand for `openai:text-embedding-3-large`. |
| `ZEROENTROPY_API_KEY` | No | none | Shorthand for `zeroentropyai:zembed-1`. |
| `VOYAGE_API_KEY` | No | none | Shorthand for `voyage:voyage-3-large`. |
| `ANTHROPIC_API_KEY` | No | none | Needed for `think` synthesis and enrichment. |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | No | generated | The `/admin` password. Min 32 chars, `[A-Za-z0-9_-]`. |
| `GBRAIN_SKIP_CONNECT_TOKEN` | No | off | Set to `1` to mint and print no token. Use `/admin` instead. |
| `GBRAIN_HTTP_CORS_ORIGIN` | No | set by template | Browser origins allowed through OAuth. Add to the list, never use `*`. |
| `BRAIN_REPO_URL` | No | none | Git URL to mirror the brain's markdown into. |
| `GITHUB_TOKEN` | No | none | Fine-grained PAT with Contents read and write, for `BRAIN_REPO_URL`. |
| `GBRAIN_FTS_LANGUAGE` | No | `english` | Search stemmer, such as `portuguese` or `spanish`. |
| `GBRAIN_ENABLE_DCR` | No | off | Set to `1` for Dynamic Client Registration (RFC 7591). |
| `GBRAIN_TOKEN_TTL` | No | `3600` | OAuth access token lifetime, in seconds. |
| `TZ` | No | `UTC` | Timezone, such as `Europe/Athens`. |
| `PORT` | No | injected | Railway sets this. Don't override it. |

Build time only: `GBRAIN_VERSION` pins the GBrain release, currently `v0.42.74.0`.

---

## Security

- **Everything that matters needs auth.** `/mcp` wants a bearer or OAuth token. `/admin` wants the bootstrap token. Only `/health` is open.
- **Every operation is scoped** `read`, `write` or `admin`. Register clients with the least they need.
- **Filesystem tools are blocked over HTTP.** `sync_brain`, `file_upload`, `file_list` and `file_url` are refused whatever the scope.
- **Tokens are hashed at rest**, and stored at mode `600` on the volume.
- **`/ingest` is off** unless you turn it on.
- **The server runs as a normal user.** The container is root only long enough to take ownership of the volume, then drops privileges.
- **Rotate the connect token** if other people can see your Railway project: `gbrain auth revoke railway && gbrain auth create <name>`.

---

## Troubleshooting

**"No embedding provider configured".** `EMBEDDING_API_KEY` is empty. Set it and redeploy.

**"No Railway volume is attached".** Without one, your next deploy would wipe the brain, so startup stops. The template attaches one, so this points at a direct Dockerfile deploy.

**"not writable".** A volume is attached but the container can't write to it. Check the mount path.

**Healthcheck failing.** First boot creates the brain and can be slow. `railway.json` allows 300 seconds. Read the Deploy Logs for the real error.

**Your agent gets a 401.** The token was rotated, or the brain was recreated. Mint a new one with `gbrain auth create my-laptop` from a Railway shell.

**Claude Desktop or ChatGPT won't connect.** Check `GBRAIN_HTTP_CORS_ORIGIN` includes their origin. The template ships both by default.

**OAuth discovery points at localhost.** No domain existed when the server started. Generate one in **Settings > Networking**, then redeploy.

**Search finds nothing after an import.** The embedding key is wrong. Run `gbrain doctor` from a Railway shell. It prints the fix.

**`expected N dimensions, not M`.** The brain was built with a different embedding provider than the one set now. `gbrain doctor` prints the fix.

**Slow during a big import.** PGLite is single-writer, so a large sync competes with the live server. See below.

---

## Scaling Past PGLite

PGLite handles personal brains up to roughly 50K pages with no second service and no connection string. Past that, switch to Postgres with pgvector:

1. Deploy Railway's **pgvector** template. The standard Postgres image does not include pgvector, so it will not work.
2. Add `DATABASE_URL=${{Postgres.DATABASE_URL}}` to this service.
3. Redeploy.

This creates a different brain rather than migrating the old one. Export and re-import if you already have content.

---

## Cost

| Component | Cost | Notes |
| --------- | ---- | ----- |
| Railway Hobby | ~$5-10/mo | One service and a small volume |
| Embeddings (OpenAI) | ~$0.13 per 1M tokens | Charged once per page |
| `think` synthesis | per call | Only when you use it |

Storage is the cheap part. Embedding a 10K-page brain costs a few dollars once.

---

## How It Works

[docs/architecture.md](docs/architecture.md) covers the boot sequence, the persistence model, and why the container is shaped this way. [docs/railway-template-setup.md](docs/railway-template-setup.md) records the Railway template configuration.

## License

MIT. GBrain itself is MIT licensed and built by [Garry Tan](https://github.com/garrytan/gbrain).

<sub>A community-maintained deployment template. Not affiliated with or officially supported by the GBrain project, Anthropic, or Railway.</sub>
