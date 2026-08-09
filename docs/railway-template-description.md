# Deploy and Host GBrain on Railway

Your AI agent forgets everything the moment the conversation ends. GBrain is the memory it has been missing: a knowledge base your agent can search, write to and reason over, at a URL any MCP client can reach.

## About Hosting GBrain

Most search tools hand back a list of pages and leave the reading to you. GBrain reads them and writes the answer, with citations, and tells you what it doesn't know yet. Every page it stores is wired into a knowledge graph as you go.

[GBrain](https://github.com/garrytan/gbrain) was built by Garry Tan to run his own agents, on his own infrastructure. This template is the shortest path to that. One Railway service with the database built in. No second service, no connection string, nothing that phones home.

## Common Use Cases

- **Give your coding agent real memory.** Claude Code, Cursor, Windsurf and Codex recall past decisions and project context instead of starting cold every session.
- **Keep a personal brain that answers back.** Capture notes from any device, then ask a question and get a written answer with sources.
- **Share what your team knows.** Point everyone's agents at one brain, with scoped access per client.

## Dependencies for GBrain Hosting

- **An embedding API key.** OpenAI, ZeroEntropy, Voyage or Google. This is the only value you provide, and the service will not start without one.

### Deployment Dependencies

- [GBrain](https://github.com/garrytan/gbrain), the brain and MCP server
- [Model Context Protocol](https://modelcontextprotocol.io), how AI clients talk to it
- [Railway Volumes](https://docs.railway.com/volumes), where the brain lives

### Implementation Details

Four steps, all written out below. You do not need to read anything on GitHub.

## Step 1: Deploy

Railway shows a short form first. Only one field needs you: paste your embedding API key into `EMBEDDING_API_KEY`. Leave everything else alone, including the optional variables at the bottom.

Click deploy. The volume and the public domain come with the template, so there is nothing to attach or generate. The first build takes a few minutes.

Using a provider other than OpenAI? Set `EMBEDDING_MODEL` to match your key:

| EMBEDDING_MODEL | Key you paste |
| --------------- | ------------- |
| openai:text-embedding-3-large | OpenAI, starts sk- |
| zeroentropyai:zembed-1 | ZeroEntropy, starts ze- |
| voyage:voyage-3-large | Voyage, starts pa- |
| google:gemini-embedding-001 | Google AI Studio |

**Pick your provider before you add anything.** GBrain fixes the vector size when it creates the brain, so switching later means re-embedding everything.

## Step 2: Collect Three Values

Open your new project on [railway.com](https://railway.com) and click the **gbrain** service. All three are on that screen.

**Your domain.** **Settings** tab, scroll to **Networking**. It looks like `gbrain-production-a1b2.up.railway.app`. That gives you two addresses: `/mcp` for your agent, and `/admin/` for you. Every example below says `your-app.up.railway.app`, so swap in yours.

**Your token.** **Deployments** tab, open the latest deploy and read the log. The first successful boot prints a block containing `gbrain_a1b2c3...`. Copy that value. It is printed once, so save it. If you lost it, open a Railway shell on the service and run `gbrain auth create my-laptop`.

**Your admin password.** **Variables** tab, find `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` and click the eye icon to reveal it. This is a different value from the token above, and it is the one people mix up.

## Step 3: Connect Your Agent

Find yours. Each section stands alone.

### Claude Code

```bash
claude mcp add --transport http gbrain https://your-app.up.railway.app/mcp \
  --header "Authorization: Bearer gbrain_a1b2c3..."
```

Check it with `claude mcp list`.

### Cursor

Put this in `~/.cursor/mcp.json`, set `GBRAIN_TOKEN` in your environment, then turn the server on under **Customize** in the sidebar.

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

### Windsurf

Put this in `~/.codeium/windsurf/mcp_config.json`, set `GBRAIN_TOKEN`, then restart Windsurf.

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

### Codex

Put this in `~/.codex/config.toml`, export `GBRAIN_TOKEN`, then restart Codex. Check it with `codex mcp list`.

```toml
[mcp_servers.gbrain]
url = "https://your-app.up.railway.app/mcp"
bearer_token_env_var = "GBRAIN_TOKEN"
```

### Claude Desktop

**Settings > Integrations**, add an integration with your `/mcp` URL, set authentication to bearer token and paste your token.

### Claude Cowork

An Organization Owner does this once: **Organization Settings > Connectors**, create a connector with your `/mcp` URL, then set bearer token authentication under Advanced Settings.

### ChatGPT

ChatGPT signs in through OAuth, so register a client first.

1. Open `https://your-app.up.railway.app/admin/` and click **Or paste bootstrap token manually**. Paste your `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` and submit.
2. Click **Register client**. Name it `chatgpt`, grant type `authorization_code`, scopes `read` and `write`. Leave `admin` unchecked.
3. For the redirect URI, copy the one ChatGPT shows on its connector setup screen.
4. Register, then copy the `client_id`. There is no client secret for this type.
5. In ChatGPT: **Settings > Connectors > Add connector**. Enter your `/mcp` URL and the client ID, click **Connect**, then approve the consent screen.

### Perplexity

Needs Pro, and a client registered first.

1. Open `https://your-app.up.railway.app/admin/` and click **Or paste bootstrap token manually**. Paste your `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` and submit.
2. Click **Register client**. Name it `perplexity`, grant type `client_credentials`, scopes `read` and `write`.
3. Register, then copy both the `client_id` and `client_secret`. They show once.
4. In Perplexity: **Settings > Connectors**. Add a remote connector with your `/mcp` URL, choose OAuth client credentials, paste both values and save.

### Check it worked

Ask your agent to remember something. Start a new chat and ask for it back.

## Step 4: Use the Dashboard

The dashboard is a page served by your own deployment, not by Railway. Open `https://your-app.up.railway.app/admin/` in any browser.

> **Keep the trailing slash.** `/admin/` works. `/admin` does not load properly.

You get a screen saying **This is a protected dashboard**, with two ways past it.

**With an agent already connected**, ask it: `Give me the GBrain admin login link`. It returns a link that works once. Ask again next time.

**With nothing connected yet**, click **Or paste bootstrap token manually**, paste your `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` into the **Admin Token** box and hit **Submit**. This is the route to use when setting up ChatGPT or Perplexity.

Inside you can register clients with the scopes and grant type you choose, watch a live feed of what your agents are doing, and read request logs. Parameters are redacted by default.

## If Something Goes Wrong

**Deploy fails with "No embedding provider configured".** `EMBEDDING_API_KEY` is empty. Set it in Variables and redeploy.

**Your agent gets a 401.** The token was rotated or the brain was recreated. Run `gbrain auth create my-laptop` from a Railway shell.

**The dashboard rejects your token.** You are pasting the connect token from the logs. The manual box wants `GBRAIN_ADMIN_BOOTSTRAP_TOKEN`, which does not start with `gbrain_`.

**The dashboard looks broken.** Check the trailing slash.

**A login link says it is invalid.** They are single-use. Ask for a new one.

**Claude Desktop, Cowork, ChatGPT or Perplexity will not connect.** These sign in through a browser, so their origin must be allowed. `GBRAIN_HTTP_CORS_ORIGIN` ships set to `https://claude.ai,https://chatgpt.com`. Add to that list rather than replacing it, and never use `*`.

**Search returns nothing after an import.** The embedding key is wrong. Run `gbrain doctor` from a Railway shell for the exact fix.

## Why Deploy GBrain on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying GBrain on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

<sub>A community-maintained template, not affiliated with or officially supported by the GBrain project. GBrain is built by Garry Tan and licensed MIT.</sub>
