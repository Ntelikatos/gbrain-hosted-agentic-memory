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

Three steps. Deploy it, connect your agent, then open the dashboard.

### 1. Deploy on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/SQ3-sz?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway shows a short form first. You only have to fill in one field.

| Field | What to do |
| ----- | ---------- |
| `EMBEDDING_API_KEY` | Paste your key. This is the only required field. |
| `EMBEDDING_MODEL` | Leave it, unless you use a provider other than OpenAI. |
| `GBRAIN_HTTP_CORS_ORIGIN` | Leave it. |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | Leave it. Railway generates one per deploy. |
| `ANTHROPIC_API_KEY`, `BRAIN_REPO_URL`, `GITHUB_TOKEN` | Optional. Leave them empty. |

Click deploy. The volume and the public domain come with the template, so there is nothing to attach or generate. The first build takes a few minutes.

**Which key do I paste?** GBrain reads the provider from the part before the colon in `EMBEDDING_MODEL`.

| `EMBEDDING_MODEL` | Key you paste | Dimensions |
| ----------------- | ------------- | ---------- |
| `openai:text-embedding-3-large` | OpenAI, starts `sk-` | 1536 |
| `zeroentropyai:zembed-1` | ZeroEntropy, starts `ze-` | 2560 |
| `voyage:voyage-3-large` | Voyage, starts `pa-` | 1024 |
| `google:gemini-embedding-001` | Google AI Studio | varies |

`openrouter` and `dashscope` work too. Local providers (`ollama`, `llama-server`, `litellm`) need no hosted key, so clear `EMBEDDING_API_KEY` after the first deploy.

> **Pick your provider before you add anything.** GBrain fixes the vector size
> when it creates the brain. Switching later means re-embedding everything.

### 2. Connect Your Agent

Open the **Deploy Logs** and find this block from the first boot:

```
======================================================================
  CONNECT YOUR AGENT — this token is shown ONCE, right now.
======================================================================
  gbrain connect https://your-app.up.railway.app/mcp \
      --token gbrain_a1b2c3... --install
```

Copy the `gbrain_...` value. That is your token. It is printed once, on the boot that created it. If you miss it, mint a new one from a Railway shell with `gbrain auth create my-laptop`.

Now pick your agent. Replace the URL and the token in each example.

**Claude Code**

```bash
claude mcp add --transport http gbrain https://your-app.up.railway.app/mcp \
  --header "Authorization: Bearer gbrain_a1b2c3..."
```

**Cursor**

Put this in `~/.cursor/mcp.json`, then turn the server on under **Customize** in the sidebar.

```json
{
  "mcpServers": {
    "gbrain": {
      "url": "https://your-app.up.railway.app/mcp",
      "headers": { "Authorization": "Bearer ${env:GBRAIN_TOKEN}" }
    }
  }
}
```

**Windsurf**

Put this in `~/.codeium/windsurf/mcp_config.json`.

```json
{
  "mcpServers": {
    "gbrain": {
      "serverUrl": "https://your-app.up.railway.app/mcp",
      "headers": { "Authorization": "Bearer ${env:GBRAIN_TOKEN}" }
    }
  }
}
```

**Codex**

Put this in `~/.codex/config.toml`, export `GBRAIN_TOKEN`, then restart Codex. Check it with `codex mcp list`.

```toml
[mcp_servers.gbrain]
url = "https://your-app.up.railway.app/mcp"
bearer_token_env_var = "GBRAIN_TOKEN"
```

**Claude Desktop and Claude Cowork**

Desktop: **Settings > Integrations**, add the `/mcp` URL, set authentication to bearer token and paste yours. Cowork: **Organization Settings > Connectors**, same URL, bearer token under Advanced Settings.

**ChatGPT**

1. In `/admin`, click **Register client**. Name it `chatgpt`, grant type `authorization_code`, scopes `read` and `write`. Leave `admin` unchecked.
2. For the redirect URI, copy the one ChatGPT shows on its connector screen.
3. Save the `client_id` from the modal. There is no client secret.
4. In ChatGPT: **Settings > Connectors > Add connector**. Paste the `/mcp` URL and the client ID, then click **Connect**.

**Perplexity** (Pro required)

1. In `/admin`, click **Register client**. Name it `perplexity`, grant type `client_credentials`, scopes `read` and `write`.
2. Copy the `client_id` and `client_secret` from the modal. They show once.
3. In Perplexity: **Settings > Connectors**. Add a remote connector with the `/mcp` URL, choose OAuth client credentials, paste both values and save.

**Check it works.** Ask your agent to remember something, then start a new chat and ask for it back. If it answers, the brain is wired up.

### 3. Use the Admin Dashboard

Go to `https://your-app.up.railway.app/admin`. The password is `GBRAIN_ADMIN_BOOTSTRAP_TOKEN`, which you read from the service **Variables** tab in Railway. It is not printed in the logs.

You can do three things there:

- **Register a client.** Give it a name, tick the scopes it needs, pick a grant type. `client_credentials` for machine access, `authorization_code` for browser sign-in. Credentials appear once, so copy them.
- **Watch live activity.** A running feed of what your agents are doing.
- **Read request logs.** Parameters are redacted by default.

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
