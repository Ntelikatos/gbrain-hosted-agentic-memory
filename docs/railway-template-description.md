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

Deploy it, collect three values from your Railway project, connect your agent, then open your dashboard. Every step is written out below, including one section per agent. You do not need to read anything on GitHub.

---

## Step 1: Deploy

Railway shows a short form before it creates anything. You only have to fill in one field.

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

**Pick your provider before you add anything.** GBrain fixes the vector size when it creates the brain. Switching later means re-embedding everything.

---

## Step 2: Find Your URL, Your Token and Your Password

Three things live in your new Railway project, and you need all three. Open [railway.com](https://railway.com), go to your project, and click the **gbrain** service. Everything below is on that screen.

### Your URL

Open the **Settings** tab, then scroll to **Networking**. Under Public Networking there is a domain that looks like `gbrain-production-a1b2.up.railway.app`. The template generates it on the first deploy, so it is already there.

That domain gives you two addresses. Write them down:

| Address | What it is for |
| ------- | -------------- |
| `https://your-domain.up.railway.app/mcp` | The address your agent connects to |
| `https://your-domain.up.railway.app/admin` | The dashboard you log in to yourself |

Every example below says `your-app.up.railway.app`. Swap in the domain you just found.

### Your token

This is what your agent authenticates with. Open the **Deployments** tab, click the most recent deploy, and read the build and deploy log. Near the end of the first successful boot you will see this block:

```
======================================================================
  CONNECT YOUR AGENT — this token is shown ONCE, right now.
======================================================================
  gbrain connect https://your-app.up.railway.app/mcp \
      --token gbrain_a1b2c3... --install
```

Copy the `gbrain_...` value. That is your token, and you will paste it into whichever agent you use below.

It is printed once, on the boot that created it, so save it somewhere. If you already lost it, open a Railway shell on the service (the three-dot menu on the service, then **Shell**) and run `gbrain auth create my-laptop` for a fresh one.

### Your admin password

This is separate from the token above, and it is the one people miss. Open the **Variables** tab on the same service and find `GBRAIN_ADMIN_BOOTSTRAP_TOKEN`. Click the eye icon to reveal it, then copy the value.

That long string is your password for the dashboard. Railway generated it when you deployed, it is unique to your project, and it is deliberately kept out of the logs. There is no username.

---

## Step 3: Connect Your Agent

Find yours below. Each one is complete on its own.

### Claude Code

One command:

```bash
claude mcp add --transport http gbrain https://your-app.up.railway.app/mcp \
  --header "Authorization: Bearer gbrain_a1b2c3..."
```

Check it landed with `claude mcp list`.

### Cursor

Create or edit `~/.cursor/mcp.json`:

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

Set `GBRAIN_TOKEN` in your environment to the token from Step 2. Then open **Customize** in the Cursor sidebar and turn the server on.

Use `.cursor/mcp.json` inside a project instead if you only want it there.

### Windsurf

Create or edit `~/.codeium/windsurf/mcp_config.json`:

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

Set `GBRAIN_TOKEN` in your environment to the token from Step 2, then restart Windsurf.

### Codex

Add this to `~/.codex/config.toml`:

```toml
[mcp_servers.gbrain]
url = "https://your-app.up.railway.app/mcp"
bearer_token_env_var = "GBRAIN_TOKEN"
```

Export the token, then restart Codex:

```bash
export GBRAIN_TOKEN=gbrain_a1b2c3...
```

Check it with `codex mcp list`.

### Claude Desktop

1. Open **Settings > Integrations**.
2. Add an integration with the URL `https://your-app.up.railway.app/mcp`.
3. Set authentication to bearer token and paste your token from Step 2.
4. Save.

### Claude Cowork

For a team plan, an Organization Owner does this once:

1. Open **Organization Settings > Connectors**.
2. Create a connector with the URL `https://your-app.up.railway.app/mcp`.
3. Under Advanced Settings, choose bearer token authentication and paste your token.
4. Save.

### ChatGPT

ChatGPT signs in through OAuth, so it needs a client registered first.

1. Open your dashboard at `https://your-app.up.railway.app/admin` in a browser. Paste the `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` value from Step 2 to log in. There is no username.
2. Click **Register client**. Name it `chatgpt`, set the grant type to `authorization_code`, and tick the `read` and `write` scopes. Leave `admin` unchecked.
3. For the redirect URI, copy the one ChatGPT shows on its own connector setup screen.
4. Click **Register**, then copy the `client_id` from the popup. There is no client secret for this type of client.
5. In ChatGPT, open **Settings > Connectors** and click **Add connector**.
6. Enter `https://your-app.up.railway.app/mcp` as the server URL, paste the client ID, and click **Connect**.
7. Approve the consent screen ChatGPT opens.

### Perplexity

Needs a Pro subscription, and a client registered first.

1. Open your dashboard at `https://your-app.up.railway.app/admin` in a browser. Paste the `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` value from Step 2 to log in. There is no username.
2. Click **Register client**. Name it `perplexity`, set the grant type to `client_credentials`, and tick the `read` and `write` scopes.
3. Click **Register**, then copy both the `client_id` and the `client_secret`. They are shown once.
4. In Perplexity, open **Settings > Connectors**.
5. Add a remote connector with the URL `https://your-app.up.railway.app/mcp`.
6. Choose OAuth client credentials, paste the client ID and secret, and save.

### Check it worked

Ask your agent to remember something. Start a new chat and ask for it back. If it answers, the brain is wired up.

---

## Step 4: Use the Dashboard

The dashboard is a web page served by your own deployment. It is not part of Railway, and it is not a separate app to install. It lives at your domain with `/admin` on the end.

1. Open `https://your-app.up.railway.app/admin` in any browser, using the domain you found in Step 2.
2. You get a single box asking for a token. There is no username.
3. Paste the `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` value from your service **Variables** tab, and log in.

If the page will not load at all, check **Settings > Networking** on the service. A domain has to exist for anything to answer.

Three things live there:

- **Register a client.** Give it a name, tick the scopes it needs, and pick a grant type. Use `client_credentials` for machine access and `authorization_code` for browser sign-in. Credentials are shown once, so copy them straight away.
- **Live activity.** A running feed of what your connected agents are doing.
- **Request logs.** What was called and when. Parameters are redacted by default.

---

## If Something Goes Wrong

**Deploy fails with "No embedding provider configured".** `EMBEDDING_API_KEY` is empty. Set it in Variables and redeploy.

**Your agent gets a 401.** The token was rotated, or the brain was recreated. Open a Railway shell and run `gbrain auth create my-laptop` for a new one.

**The dashboard rejects your password.** You are probably pasting the connect token from the deploy logs. Those are two different values. The dashboard wants `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` from the **Variables** tab, and it starts with neither `gbrain_` nor anything else recognisable.

**`/admin` does not load at all.** Check **Settings > Networking** on the service. If there is no public domain, generate one and redeploy.

**Claude Desktop, Cowork, ChatGPT or Perplexity will not connect.** These sign in through a browser, so their origin has to be allowed. The template ships `GBRAIN_HTTP_CORS_ORIGIN` set to `https://claude.ai,https://chatgpt.com`. Add your client's origin to that list rather than replacing it, and never set it to `*`.

**Search returns nothing after an import.** The embedding key is wrong or missing. Open a Railway shell and run `gbrain doctor`. It prints the exact fix.

**You see `expected N dimensions, not M`.** The brain was built with a different embedding provider than the one configured now. `gbrain doctor` prints the fix.

---

## What You Get

- **A brain over MCP.** 30+ tools at `/mcp`, with OAuth 2.1 and scoped access
- **No database to run.** PGLite (Postgres compiled to WebAssembly) rides along inside the service
- **Answers, not just results.** Hybrid search across vectors, keywords and a self-building knowledge graph
- **An admin dashboard.** Live activity, connected clients and request logs
- **Storage that survives.** Brain, config and tokens persist across redeploys, with Railway backups a click away
- **A pinned release.** The image ships a known-good GBrain version, so redeploying never changes behavior underneath you

Comfortable at the scale of a personal or small-team brain, roughly tens of thousands of pages. Beyond that, point it at Postgres with pgvector instead.

## Why Deploy GBrain on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GBrain on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

---

<sub>A community-maintained deployment template, not affiliated with or officially supported by the GBrain project. GBrain is built by Garry Tan and licensed MIT. All trademarks belong to their respective owners.</sub>
