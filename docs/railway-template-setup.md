# The Railway template

**Published:** <https://railway.com/deploy/SQ3-sz>

Carries the service, a volume at `/data`, a public domain on port 8080, and the
four variables below.

The goal: the deploy page asks for one thing — the embedding API key — and
everything else is either prefilled or provisioned by the template.

## Editing it

Templates can only be edited in the composer UI; there is no API for it. So the
variable table below is the source of truth, and the composer has to be brought
in line with it by hand.

[Templates](https://railway.com/workspace/templates) → open the template →
select the **gbrain** service → **Variables** → add each row from the table
below with its description → **Update Template**. Existing deployments are
unaffected; new ones pick it up.

## Recreating it from scratch

[Templates](https://railway.com/workspace/templates) → **New Template** → **Add
New** → **GitHub Repo** `Ntelikatos/gbrain-hosted-agentic-memory`, branch `main`
→ **Settings** → **Public Networking**, HTTP port `8080` → **Variables**, add
all four from the table below → right-click the service → **Attach Volume**,
mount path `/data` → **Create Template** → **Publish**.

⚠️ **Do not use Generate Template from Project.** It captures the reference
project's variables as *concrete values* — which would ship that project's
`EMBEDDING_API_KEY` to every deployer, and freeze
`GBRAIN_ADMIN_BOOTSTRAP_TOKEN` at one resolved value instead of regenerating it
per deploy. It also captures no descriptions, so nothing is labelled on the
deploy page. It looks like the convenient path and it is the wrong one.

## Variables

Enter all four in the composer's **Variables** tab, each with the description
shown. Descriptions are not decoration — they are the label the deployer reads
on the deploy page.

| Name | Value | Description to enter |
| --- | --- | --- |
| `EMBEDDING_API_KEY` | *(leave empty)* | Your API key for the provider named in EMBEDDING_MODEL. OpenAI keys start with sk-. Search cannot work without one, so the service will not start until this is set. |
| `EMBEDDING_MODEL` | `openai:text-embedding-3-large` | Which embedding model builds the search index, as provider:model. Change the provider here if you are not using OpenAI — see the README for the supported list. Pick before your first ingest; changing it later means re-embedding everything. |
| `GBRAIN_HTTP_CORS_ORIGIN` | `https://claude.ai,https://chatgpt.com` | Browser origins allowed to complete the OAuth handshake. Needed for Claude Desktop and ChatGPT; CLI clients like Claude Code work without it. Add to the list rather than replacing it. |
| `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` | `${{secret(64, "abcdef0123456789")}}` | Password for the /admin dashboard. Generated per-deploy — read it from this variable rather than the deploy logs. |

Plus three optional ones, all empty. Each description **must** open with
"Optional — leave empty", because the description is the only label the
deployer sees and an empty field otherwise reads as required:

| Name | Value | Description to enter |
| --- | --- | --- |
| `ANTHROPIC_API_KEY` | *(empty)* | Optional — leave empty. Lets `gbrain think` write a cited answer instead of returning search results. Memory, search, and the knowledge graph all work without it. |
| `BRAIN_REPO_URL` | *(empty)* | Optional — leave empty. Git URL of a GitHub repo to mirror your brain's markdown into, so it is readable and portable outside Railway. Empty keeps the brain repo local to the volume. |
| `GITHUB_TOKEN` | *(empty)* | Optional — leave empty. Fine-grained GitHub PAT with read/write Contents access. Only needed if BRAIN_REPO_URL points at a private repo. |

Empty is safe for all three, on two independent counts.

Railway simply does not create a variable the deployer left blank. Confirmed on
a real deploy from this template: all seven were declared, three were left
empty, and the resulting service carried exactly the four that had values. So an
empty declared variable is optional in practice — it renders a field on the
deploy page and nothing else.

And even if a blank one *were* injected as `VAR=""`, nothing breaks:
`BRAIN_REPO_URL` and `GITHUB_TOKEN` are guarded with `[ -n "${VAR:-}" ]`, so an
empty `GITHUB_TOKEN` never writes a credential-less
`url.https://oauth2:@github.com/.insteadOf` rewrite into git config;
`ANTHROPIC_API_KEY` is never read by this repo at all, and GBrain reports
`NO_ANTHROPIC_API_KEY` identically whether it is empty or absent. Verified by
booting with all three set to `""`.

The practical consequence: these three cost nothing at runtime. Their only cost
is a field on the deploy page, which is why the "Optional — leave empty" prefix
on each description is doing the real work.

Anything else optional should stay *out* of the template. Every declared
variable is another field between the deployer and a working brain, and the
README already documents the full set.

### Why the variables must be declared here

A template variable declared with an **empty value** is what makes Railway
render a required input field on the template's deploy page, *before* the
project is created. Railway's own docs describe the deploy flow this way: "A
ghost service will appear, asking you to configure the template's variables."

An earlier version of this doc said "Variables: deliberately none," reasoning
that a deployer's API key is a secret and cannot be shipped in a template. The
premise is right and the conclusion was wrong: declaring a variable with an
empty value ships no value at all. It only tells Railway to ask. Declaring
nothing does not protect the key — it just means the deployer lands in a
deployed-but-broken project and has to find the variables by hand, which is
exactly the failure this template exists to prevent.

So: declare all four, and let the *value* column decide what ships. Only
`EMBEDDING_API_KEY` is left empty, because only it is a secret.

### Why each one

**`EMBEDDING_API_KEY`** — empty, so the deploy page requires it. This is the one
manual step, and there is no way around it: it is the deployer's own credential.

**`EMBEDDING_MODEL`** — prefilled with the OpenAI default. This is a change of
position: the earlier reasoning was that defaulting it would push everyone onto
one vendor. But the deployer sees the field and can edit it, and the alternative
is forcing every deployer to know the exact `provider:model` string before they
can deploy anything. A visible, editable default is a suggestion; an empty
required field is a quiz. The boot script accepts any supported provider and
routes the key accordingly.

**`GBRAIN_HTTP_CORS_ORIGIN`** — prefilled. GBrain rejects every cross-origin
request to its OAuth endpoints unless origins are allowlisted. Bearer-token CLI
clients (Claude Code, Codex, Cursor) do not care, but Claude Desktop/Cowork and
ChatGPT cannot connect at all — and they fail *silently*, so a deployer
discovers it only when the handshake never finishes. Plain value, not a
`${{...}}` function. Never `*`: that would let any page in any browser drive the
deployer's OAuth endpoints.

**`GBRAIN_ADMIN_BOOTSTRAP_TOKEN`** — a `secret()` function, so every deploy gets
its own. Railway's template best practices are explicit here: "For any secrets,
passwords, keys, etc., use template variable functions to generate them, avoid
hardcoding default credentials at all costs." It also keeps the admin token out
of the deploy logs — the boot script only generates and prints one when this is
unset. 64 hex chars satisfies GBrain's `[A-Za-z0-9_-]{32,}` requirement, which
the boot script validates before the server starts.

⚠️ Type this one into the composer **by hand** and confirm it is stored as
`${{secret(...)}}`. A template generated from a live project captures the
*concrete* value the project resolved it to, which would hand every deployer the
same admin token.

### Not declared

The connect token. GBrain generates token values itself — `gbrain auth create`
has no flag to supply one — so it cannot be seeded from a variable. It is minted
on first boot and printed once. Deployers who would rather not have it in the
deploy log set `GBRAIN_SKIP_CONNECT_TOKEN=1` and mint clients from `/admin`.

Details and reasoning for the remaining settings follow.

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
