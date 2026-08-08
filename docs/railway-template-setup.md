# The Railway template

> **No template is published right now.** The previous one was deleted. The
> fastest way to recreate it is **Generate Template from Project** against the
> pre-configured `gbrain-template-source` project, rather than building one from
> scratch in the composer — that project already has the volume and public domain
> attached.

The goal: the only thing a deployer sets is their embedding API key.

## Recommended: generate from the reference project

The `gbrain-template-source` project already has the service, a volume mounted at
`/data`, and a public domain on port 8080.

1. Open that project → **Settings** (top right of the canvas).
2. Scroll to **Generate Template from Project** → **Create Template**.
3. Confirm the captured settings in the composer. Check that the volume and the
   public domain came across.
4. **Create Template**, then **Publish**.
5. Put the template URL in the README's deploy button (an HTML comment marks the
   spot).

## Or build one from scratch

1. [railway.com/workspace/templates](https://railway.com/workspace/templates) → **New Template**.
2. **Add New** → **GitHub Repo** → `Ntelikatos/gbrain-hosted-agentic-memory`, branch `main`.
3. **Settings** tab → **Public Networking** → HTTP on port `8080`.
4. Right-click the service → **Attach Volume** → mount path `/data`.
5. **Create Template**, then **Publish**.

## Variables

Deliberately none.

`OPENAI_API_KEY` is the deployer's own secret and cannot be shipped in a
template. Everything else the container needs it generates for itself: the admin
dashboard token and the connect token are both created on first boot, printed
once, and persisted to the volume.

An earlier version of this doc suggested shipping
`GBRAIN_ADMIN_BOOTSTRAP_TOKEN` = `${{secret(64, "abcdef0123456789")}}`. That
still works and keeps the admin token out of the deploy logs, which is a real
benefit. But it is optional now, and a template generated from a project would
capture a *concrete* value rather than the function — which would hand every
deployer the same admin token. If you add it, type the function into the
composer by hand and confirm it is stored as `${{secret(...)}}`.

Details and reasoning for each setting follow.

## Service source

| Field | Value |
| --- | --- |
| Source | GitHub repo: `https://github.com/Ntelikatos/gbrain-hosted-agentic-memory` |
| Branch | default (append `/tree/<branch>` to the URL to pin another one) |
| Root directory | *(leave empty)* |

Railway builds the Dockerfile automatically. `railway.json` supplies the
healthcheck path, restart policy, and drain window, so none of that needs
re-entering in the composer.

## Attach a volume

Right-click the service on the canvas → **Attach Volume**.

| Field | Value |
| --- | --- |
| Mount path | `/data` |

This is the single highest-value setting in the template. Without it a deployer
has to know to add a volume before their brain becomes permanent, and the
failure is invisible until their second deploy. With it attached here, they
never think about it.

The boot script reads Railway's `RAILWAY_VOLUME_MOUNT_PATH`, so a different
mount path also works — `/data` just matches the docs.

## Enable public networking

Settings tab → **Public Networking** → enable HTTP on port `8080`.

A domain is then generated at deploy time, which means `RAILWAY_PUBLIC_DOMAIN`
is present on the very first boot. That matters beyond convenience: GBrain
advertises that domain as its OAuth issuer, and RFC 8414 requires the issuer to
match the URL clients actually hit. Deployers who generate a domain later have
to redeploy for discovery metadata to be correct.

Use HTTP, not TCP Proxy — this is an HTTPS MCP endpoint, not a raw socket.

## Variables

| Variable | Value | Notes |
| --- | --- | --- |
| `OPENAI_API_KEY` | *(empty — deployer fills in)* | Required. The one thing they must supply. |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | `${{secret(64, "abcdef0123456789")}}` | Generated per deploy. |

`${{secret(length, alphabet)}}` is a [template variable
function](https://docs.railway.com/templates/create#template-variable-functions):
Railway executes it at deploy time and substitutes the result.

**Pass the alphabet explicitly.** GBrain rejects any admin token containing a
character outside `[A-Za-z0-9_-]`, and Railway documents `secret()`'s default
length but not its default alphabet. `secret(64, "abcdef0123456789")` is 64 hex
characters, which is unambiguously valid and comfortably over GBrain's 32-char
minimum. A bare `${{secret(32)}}` is a gamble on an undocumented default that
would fail at boot.

This also means the admin token never appears in a deploy log — the deployer
reads it from the Variables tab whenever they need `/admin`.

### Optional variables worth listing

Add these with empty values so they show up as recognized knobs:

| Variable | Purpose |
| --- | --- |
| `ANTHROPIC_API_KEY` | Enables `gbrain think` synthesis |
| `GBRAIN_HTTP_CORS_ORIGIN` | Required for browser OAuth clients (ChatGPT, Claude Desktop/Cowork) |
| `BRAIN_REPO_URL` / `GITHUB_TOKEN` | GitHub-backed brain repo |

Railway has no documented way to attach help text to a variable in the deploy
form, so the README remains the place that explains them.

## Publish

Workspace → Templates → **Publish**. Then set the README's deploy button:

```md
[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/<code>?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)
```

Templates can only be edited in the composer UI — there is no API for it,
confirmed with Railway's own agent. Existing deployments are unaffected by an
edit; new ones pick it up. If you change anything there, update this file so the
two do not drift.

## Deliberately not configured

- **Serverless / app-sleeping.** Would cut idle cost, and this container sends
  no outbound traffic when idle so it would genuinely sleep. But Railway warns
  the first request to a slept service may return `502`, and a cold PGLite + Bun
  boot is not instant. For an endpoint an agent calls mid-conversation, that is
  a bad trade. Deployers who want it can enable it themselves.
- **Replicas.** Railway does not support replicas on services with volumes, and
  PGLite is single-writer regardless.
- **`overlapSeconds`.** Railway already prevents two deployments from being
  mounted to the same volume simultaneously, so there is no double-writer window
  to close.
- **Infrastructure as Code** (`.railway/railway.ts`). It models volumes and
  domains, but it is CLI-driven (`railway config apply`), explicitly
  experimental, and cannot coexist with the `railway.json` this repo uses. Wrong
  tool for a one-click template.
