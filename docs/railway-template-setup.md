# The Railway template

**Published:** <https://railway.com/deploy/SQ3-sz>

Generated from the `gbrain-template-source` project, which carries the service,
a volume at `/data`, and a public domain on port 8080.

The goal: the only things a deployer sets are `EMBEDDING_MODEL` and
`EMBEDDING_API_KEY`.

## Recreating or rebuilding it

From the reference project (keeps the volume and domain without re-entering
them): open `gbrain-template-source` → **Settings** → **Generate Template from
Project**, confirm the captured settings, **Create Template**, **Publish**.

Generation captures the reference project's variables too, so
`GBRAIN_HTTP_CORS_ORIGIN` has to be set *there* first — and check that
`EMBEDDING_API_KEY` was not captured along with it, since a template ships its
variable values to every deployer.

From scratch: [Templates](https://railway.com/workspace/templates) → **New
Template** → **Add New** → **GitHub Repo**
`Ntelikatos/gbrain-hosted-agentic-memory`, branch `main` → **Settings** →
**Public Networking**, HTTP port `8080` → **Variables**, add
`GBRAIN_HTTP_CORS_ORIGIN` = `https://claude.ai,https://chatgpt.com` →
right-click the service → **Attach Volume**, mount path `/data` → **Create
Template** → **Publish**.

## Variables

One:

| Name | Value |
| --- | --- |
| `GBRAIN_HTTP_CORS_ORIGIN` | `https://claude.ai,https://chatgpt.com` |

GBrain rejects every cross-origin request to its OAuth endpoints unless origins
are allowlisted. Bearer-token CLI clients (Claude Code, Codex, Cursor) do not
care, but Claude Desktop/Cowork and ChatGPT cannot connect at all — and they
fail *silently*, so a deployer discovers it only when their client refuses to
finish the handshake. The same two origins are right for essentially everyone,
and the value is not a secret, so it belongs in the template rather than in the
troubleshooting section.

Ship it as a plain value, not a `${{...}}` function. It is an allowlist, so a
deployer connecting from elsewhere adds their origin; `*` would let any page in
any browser drive their OAuth endpoints.

The deployer still sets `EMBEDDING_MODEL` and `EMBEDDING_API_KEY` themselves.
The key is their own secret and cannot be shipped in a template; the model is
theirs to choose, and defaulting it would quietly push everyone onto one vendor.
Everything else the container generates for itself: the admin dashboard token
and the connect token are both created on first boot, printed once, and
persisted to the volume.

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
