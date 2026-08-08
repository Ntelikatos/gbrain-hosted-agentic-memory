# GBrain Hosted Agentic Memory

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/SQ3-sz?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)

[![Docker Build](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/docker-build.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/docker-build.yml)
[![Lint Dockerfile](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/lint-dockerfile.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/lint-dockerfile.yml)
[![ShellCheck](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/shellcheck.yml)
[![Trivy Security Scan](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/trivy.yml/badge.svg)](https://github.com/Ntelikatos/gbrain-hosted-agentic-memory/actions/workflows/trivy.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Give your AI agents a memory that outlives the chat. Deploy [GBrain](https://github.com/garrytan/gbrain) on Railway and connect Claude Code, Codex, or Cursor in under 5 minutes.

## What You Get

- **A hosted brain over MCP** — 30+ tools at `https://your-app.up.railway.app/mcp`. Your agent searches, writes, and traverses a knowledge graph instead of forgetting everything between sessions.
- **Zero database setup** — PGLite (Postgres 17 compiled to WASM) runs inside the container. No second service, no connection string, brain ready in about two seconds.
- **One copy-paste to connect** — a bearer token is minted on first boot and printed with the exact `gbrain connect` command. Paste it, and your agent has a memory.
- **Synthesis, not just search** — `gbrain think` returns a cited answer plus an honest note on what the brain *doesn't* know yet, rather than ten chunks to read yourself.
- **Self-wiring knowledge graph** — every page write extracts entity references and creates typed edges with zero LLM calls.
- **Persistent storage** — the brain, its config, and your tokens live on a Railway volume and survive redeployments.
- **Admin dashboard** — live activity, registered clients, and request logs at `/admin`.
- **Pinned and reproducible** — the image pins a known-good GBrain release, so a redeploy can't silently change behavior.

---

## Deploy to Railway

### Step 1: Deploy the Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/SQ3-sz?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway shows a short form before it creates anything. **`EMBEDDING_API_KEY` is the only field you have to fill in** — the rest arrive prefilled:

| Field | What to do |
| ----- | ---------- |
| `EMBEDDING_API_KEY` | **Paste your key.** Required. See the provider table below. |
| `EMBEDDING_MODEL` | Defaults to `openai:text-embedding-3-large`. Change it if you use another provider. |
| `GBRAIN_HTTP_CORS_ORIGIN` | Defaults to `https://claude.ai,https://chatgpt.com`. Leave it. |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | Generated for you. Leave it — you'll read it back from Variables later. |
| `ANTHROPIC_API_KEY`, `BRAIN_REPO_URL`, `GITHUB_TOKEN` | Optional. Leave empty — they're there for later, and the brain works without all three. |

Then click deploy. The volume and the public domain come with the template, so there is nothing to attach or generate. The first build takes a few minutes — it installs GBrain and its PGLite engine.

**Which key?** The provider is read from the part before the colon in `EMBEDDING_MODEL`, and your key is routed to whichever variable GBrain expects for it:

| `EMBEDDING_MODEL`               | Key you paste                | Dimensions |
| ------------------------------- | ---------------------------- | ---------- |
| `openai:text-embedding-3-large` | OpenAI, starts `sk-`         | 1536       |
| `zeroentropyai:zembed-1`        | ZeroEntropy, starts `ze-`    | 2560       |
| `voyage:voyage-3-large`         | Voyage, starts `pa-`         | 1024       |
| `google:gemini-embedding-001`   | Google AI Studio             | varies     |

`openrouter` and `dashscope` are mapped too.

> **Pick before your first ingest.** GBrain resolves the embedding dimension when the brain is created, so switching providers later means re-embedding everything. The container refuses to start without a key rather than build a brain that fails on your first import with a confusing `expected N dimensions, not M`.

**Local or self-hosted providers** (`ollama`, `llama-server`, `litellm`) don't use a hosted API key — set `EMBEDDING_MODEL` plus whatever that provider needs, and clear `EMBEDDING_API_KEY` afterwards in Variables.

### Step 2: Attach a Volume (only if you didn't use the template)

The template attaches one at `/data`. Check the service — if there's a volume, skip to Step 3. Deploying straight from the Dockerfile instead:

1. Right-click the project canvas > **Add Volume**
2. Attach it to the service
3. Set the **mount path** to `/data`

Or with the [Railway CLI](https://docs.railway.com/cli), from a linked directory — creates and attaches in one command:

```bash
railway volume add --mount-path /data
```

This holds the brain database, your config, and your tokens. **Without it your entire brain is wiped on every deploy** — the container filesystem is writable, so everything would appear to work right up until the next deploy destroyed it. The boot script detects a missing volume via `RAILWAY_VOLUME_MOUNT_PATH` and refuses to start rather than let that happen. Any mount path works; `/data` is the documented default.

> **Turn on backups.** Service **Settings → Backups** offers daily, weekly, and monthly snapshots with one-click restore. PGLite is a single file holding everything you've captured; a scheduled backup is the difference between a bad afternoon and losing the brain.

### Step 3: Generate a Public Domain (only if you didn't use the template)

The template ships public networking on port 8080, so a domain exists from the first boot. Check **Settings > Networking**. If there isn't one:

1. Service **Settings** > **Networking**
2. Under **Public Networking**, click **Generate Domain**

GBrain advertises this URL as its OAuth issuer, and [RFC 8414](https://datatracker.ietf.org/doc/html/rfc8414) requires it to match the URL clients actually hit — so generate it before the server starts, and redeploy if you added it later.

### Step 4: Grab Your Connect Token

Open the **Deploy Logs**. On the first successful boot you'll see:

```
======================================================================
  CONNECT YOUR AGENT — this token is shown ONCE, right now.
======================================================================
  gbrain connect https://your-app.up.railway.app/mcp \
      --token gbrain_a1b2c3... --install
```

**Your `/admin` password** is the `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` the template generated — read it from the service **Variables** tab. It is deliberately *not* printed in the logs when the template sets it. (Deploying from the Dockerfile without that variable? Then the boot script generates one and prints it just above the connect token.)

Copy that command. It is printed **only** on the boot that created it — GBrain hides secrets from non-TTY logs on purpose, and this template prints once rather than on every restart.

**Missed it?** The token is on the volume at `/data/.gbrain/railway/connect-token`. Or mint a fresh one from a Railway shell:

```bash
gbrain auth create my-laptop
```

**Don't want a token in the deploy log?** Set `GBRAIN_SKIP_CONNECT_TOKEN=1`. Nothing is minted or printed; log into `/admin` and register clients there instead. GBrain generates token values itself, so there is no way to pre-set one as a Railway variable.

### Step 5: Connect Your Agent

Install GBrain locally, then run the command from Step 4:

```bash
git clone --depth 1 https://github.com/garrytan/gbrain.git ~/gbrain
cd ~/gbrain && bun install && bun link

gbrain connect https://your-app.up.railway.app/mcp \
    --token gbrain_a1b2c3... --install
```

`--install` wires up the MCP config and smoke-tests the token before handing off. For Codex, add `--agent codex`.

> **Do not `npm install -g gbrain`.** The npm package by that name is an unrelated project and will shadow the real binary on your PATH. GBrain is distributed from GitHub only.

### Step 6: Put Something In It

```bash
gbrain capture "Vitest is our test runner; we moved off Jest in March"
gbrain capture --file ./notes/architecture.md
```

Then ask your agent something that needs memory. Or query directly:

```bash
gbrain search "what did we decide about the test runner?"   # raw pages, no LLM cost
gbrain think  "what did we decide about the test runner?"   # cited answer + gap analysis
```

### Step 7: Back the Brain with GitHub (optional)

GBrain's system of record is a plain git repo of markdown. By default it lives on the volume. Point it at a GitHub repo to make it portable and readable from your laptop:

| Variable         | Value                                     |
| ---------------- | ----------------------------------------- |
| `BRAIN_REPO_URL` | `https://github.com/you/my-brain`         |
| `GITHUB_TOKEN`   | Fine-grained PAT with **Contents: R/W**   |

Use a [fine-grained token](https://github.com/settings/tokens?type=beta) scoped to that one repo. The boot script clones on first run and pulls on later boots. The token is injected via `git config url.insteadOf`, so it never lands in `.git/config` or `git remote -v`.

---

## Environment Variables

| Variable                       | Required | Default        | Description                                                                 |
| ------------------------------ | -------- | -------------- | --------------------------------------------------------------------------- |
| `OPENAI_API_KEY`               | No       | —              | Shorthand: implies `openai:text-embedding-3-large`.                          |
| `ZEROENTROPY_API_KEY`          | No       | —              | Shorthand: implies `zeroentropyai:zembed-1`.                                 |
| `VOYAGE_API_KEY`               | No       | —              | Shorthand: implies `voyage:voyage-3-large`.                                  |
| `EMBEDDING_MODEL`              | Yes*     | auto-detected  | `<provider>:<model>`. *Required with `EMBEDDING_API_KEY`; optional if you set a provider key directly. |
| `EMBEDDING_API_KEY`            | Yes*     | —              | Key for the provider named in `EMBEDDING_MODEL`. Routed to that provider's own variable. |
| `ANTHROPIC_API_KEY`            | No       | —              | Needed for `gbrain think` synthesis and enrichment.                          |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | No       | auto-generated | `/admin` login. Generated on first boot, printed once, and persisted to the volume. Set your own (min 32 chars, `[A-Za-z0-9_-]`) to keep it out of the logs. |
| `GBRAIN_SKIP_CONNECT_TOKEN`    | No       | off            | Set to `1` to mint no connect token and print nothing. Create clients from `/admin` instead. |
| `GBRAIN_HTTP_CORS_ORIGIN`      | No       | set by template | Comma-separated origins. The template ships `https://claude.ai,https://chatgpt.com`. Required for browser OAuth clients — see below. |
| `BRAIN_REPO_URL`               | No       | —              | Git URL for a GitHub-backed brain repo.                                      |
| `GITHUB_TOKEN`                 | No       | —              | Fine-grained PAT for `BRAIN_REPO_URL`.                                       |
| `GBRAIN_FTS_LANGUAGE`          | No       | `english`      | Full-text search stemmer, e.g. `portuguese`, `spanish`.                      |
| `GBRAIN_ENABLE_DCR`            | No       | off            | Set to `1` for Dynamic Client Registration (RFC 7591).                       |
| `GBRAIN_TOKEN_TTL`             | No       | `3600`         | OAuth access-token lifetime in seconds.                                      |
| `TZ`                           | No       | `UTC`          | Timezone, e.g. `Europe/Athens`.                                              |
| `PORT`                         | No       | injected       | Set by Railway. Don't override.                                              |

Build-time: `GBRAIN_VERSION` (default `v0.42.74.0`) pins the GBrain release. Bump it with a Railway build arg or by editing the Dockerfile.

---

## Connecting Other Clients

| Client                        | Path                                                                              |
| ----------------------------- | --------------------------------------------------------------------------------- |
| **Claude Code / Cursor**      | `gbrain connect https://your-app.up.railway.app/mcp --token <token> --install`     |
| **Codex**                     | Same, plus `--agent codex`. Reads the bearer from `$GBRAIN_REMOTE_TOKEN` at runtime. |
| **Claude Desktop / Cowork**   | Settings > Integrations > add the `/mcp` URL. **Requires `GBRAIN_HTTP_CORS_ORIGIN`.** |
| **ChatGPT**                   | OAuth 2.1 + PKCE. Register an `authorization_code` client from `/admin`. **Requires `GBRAIN_HTTP_CORS_ORIGIN`.** |

**Browser-based clients need CORS.** The server binds `0.0.0.0` so Railway's proxy can reach it, and GBrain then rejects all cross-origin requests to the OAuth endpoints unless you allowlist origins:

```
GBRAIN_HTTP_CORS_ORIGIN=https://claude.ai,https://chatgpt.com
```

The template sets exactly that, so Claude Desktop and ChatGPT work out of the
box. Edit the variable if you connect from somewhere else — it is an
allowlist, so add your origin rather than replacing the list, and don't use
`*`: it would let any page in any browser drive your OAuth endpoints.

Bearer-token CLI clients (Claude Code, Codex, Cursor) are unaffected and work
without it. Deploying from the Dockerfile rather than the template? Then it is
unset and you set it yourself.

---

## Security

- **Auth on everything that matters** — `/mcp` requires a bearer token or OAuth access token; unauthenticated requests get `401`. `/admin` is behind the bootstrap token. Only `/health` is open.
- **Scoped operations** — every MCP operation is tagged `read`, `write`, or `admin`. Register least-privilege clients from `/admin`.
- **Local-only operations are refused over HTTP** — `sync_brain`, `file_upload`, `file_list`, and `file_url` are rejected regardless of scope, so a remote agent can't reach the container's filesystem.
- **Tokens are hashed at rest** — stored SHA-256 hashed, and on the volume at mode `600`.
- **`/ingest` is off by default** — the webhook ingestion endpoint stays disabled unless you deliberately enable it. Fewer unauthenticated doors into a brain full of personal notes.
- **Redacted request logs** — `mcp_request_log` records a redacted parameter summary by default; payload sizes are rounded so they can't be used to probe secret content.
- **Non-root** — the server runs as an unprivileged `gbrain` user. The container starts as root only long enough to take ownership of the volume (Railway mounts volumes as root), then drops privileges via `setpriv` before any GBrain code runs. You do **not** need Railway's `RAILWAY_RUN_UID=0` workaround, and setting it would keep the server running as root.
- **Rotate the connect token** if your Railway project has other members: `gbrain auth revoke railway && gbrain auth create <name>`.

---

## Troubleshooting

**Deploy fails with "No embedding provider configured"** — `EMBEDDING_API_KEY` is empty. Set it in Variables (with `EMBEDDING_MODEL` naming the provider) and redeploy. See Step 1.

**Deploy fails with "No Railway volume is attached to this service"** — Exactly what it says: without one the brain would be destroyed by your next deploy, so startup stops. Attach one (Step 2) and redeploy. The template does this for you, so this points at a direct Dockerfile deploy.

**Deploy fails with "not writable"** — A volume is attached but the container can't write to it. Check the mount path in the volume settings.

**Healthcheck failing / service marked unhealthy** — First boot creates the brain and can exceed the default healthcheck window; `railway.json` allows 300s. Check Deploy Logs for the real error.

**`gbrain connect` fails with 401** — The token was rotated or the brain was recreated. Mint a new one: `gbrain auth create my-laptop`.

**Claude Desktop or ChatGPT won't connect** — Set `GBRAIN_HTTP_CORS_ORIGIN`. See the client table above.

**OAuth discovery points at localhost** — `RAILWAY_PUBLIC_DOMAIN` wasn't set when the server started. Generate a domain (Step 3), then redeploy.

**Search returns nothing after importing** — Embeddings need a valid provider key. Run `gbrain doctor` from a Railway shell; it prints a paste-ready repair command.

**`expected N dimensions, not M`** — The brain was created with a different embedding provider than the one now configured. `gbrain doctor` prints the exact fix.

**"database is already open through `gbrain serve`" after a redeploy** — a PGLite lock left by the previous container. The boot script clears it automatically on every start; if you see this from a manual CLI command, a server really is running, so use its MCP tools instead or stop it first.

**Brain feels slow on a large sync** — PGLite is single-writer, so a big import contends with the live server. For brains beyond ~50K pages, move to Postgres + pgvector (see below).

---

## Scaling Past PGLite

PGLite is the right default: no second service, no connection string, instant startup. It handles personal brains up to roughly 50K pages.

Beyond that — or if you want cron enrichment running concurrently with the server — switch to Postgres + pgvector:

1. Deploy Railway's **pgvector** template. **Railway's standard Postgres image does not include pgvector**, so the stock Postgres template will not work.
2. Add `DATABASE_URL=${{Postgres.DATABASE_URL}}` to this service so it resolves over the private network.
3. Redeploy. GBrain picks up `DATABASE_URL` and uses the Postgres engine.

Note that this is a different brain, not a migration — export and re-import if you have existing content.

---

## Cost

| Component                | Cost       | Notes                                          |
| ------------------------ | ---------- | ---------------------------------------------- |
| Railway Hobby            | ~$5-10/mo  | One service plus a small volume                 |
| Embeddings (OpenAI)      | ~$0.13/1M tokens | `text-embedding-3-large`, one-time per page |
| `gbrain think` synthesis | per-call   | Only when you use the synthesis layer           |

Storage is the cheap part. Embedding a 10K-page brain costs a few dollars once.

---

## How It Works

See [docs/architecture.md](docs/architecture.md) for the boot sequence, the persistence model, and why the container is shaped the way it is.

[docs/railway-template-setup.md](docs/railway-template-setup.md) records the Railway template configuration, including the composer settings that would let the template provision the volume, domain, and admin token itself.

---

## License

MIT. GBrain itself is MIT-licensed and built by [Garry Tan](https://github.com/garrytan/gbrain).

<sub>This is a community-maintained deployment template. It is not affiliated with or officially supported by the GBrain project, Anthropic, or Railway.</sub>
