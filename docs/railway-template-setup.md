# The Railway template

**Published:** <https://railway.com/deploy/w2yM4N>

> **Current state:** the template deploys the service, but does **not** yet
> attach a volume, generate a domain, or set variables — verified against a live
> deploy on 2026-08-08, which stopped at "No Railway volume is attached". Adding
> the three settings below removes those steps from the README for everyone who
> deploys it.

Settings to enter in Railway's template composer. Configuring these is what turns
eight README steps into four: the volume, the public domain, and the admin token
come pre-configured instead of being manual setup.

## Steps

1. Go to [railway.com/workspace/templates](https://railway.com/workspace/templates) → **New Template**.
2. **Add New** (top right) → choose **GitHub Repo** → `Ntelikatos/gbrain-hosted-agentic-memory`.
3. **Variables** tab → add `OPENAI_API_KEY` (leave the value empty) and
   `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` = `${{secret(64, "abcdef0123456789")}}`.
4. **Settings** tab → **Public Networking** → enable HTTP on port `8080`.
5. Right-click the service → **Attach Volume** → mount path `/data`.
6. Click **Create Template**.
7. Deploy it once into a throwaway project to check the volume mounts and the
   brain comes up, then delete that project.
8. **Publish** from the templates page.

Steps 3 to 5 are the ones currently missing from the published template. Editing
it in the composer applies them to future deploys; existing projects are
unaffected.

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

Workspace → Templates → **Publish**. The README's deploy button now points at the
published template:

```md
[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/w2yM4N?referralCode=fhlcDU&utm_medium=integration&utm_source=template&utm_campaign=generic)
```

Editing the template later (to change a variable, or the mount path) is done in
the same composer; existing deployments are unaffected, but new ones pick the
change up. If you change anything here, update this file so the two do not
drift.

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
