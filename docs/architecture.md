# Architecture

How this container is put together, and why.

## Shape

One service, one volume, no database server.

```
Railway edge (HTTPS, $PORT)
        │
        ▼
  tini (PID 1)
        │
        ├── entrypoint.sh
        │     └── init-gbrain.sh        one-shot, idempotent
        │
        └── exec gbrain serve --http    becomes the container process
                  │
                  ├── /mcp      MCP, bearer + OAuth 2.1, scope-gated
                  ├── /admin    dashboard, bootstrap-token auth
                  ├── /health   open; Railway healthcheck target
                  └── /ingest   webhook (off by default)
                          │
                          ▼
                  /data  (Railway volume)
                  ├── .gbrain/
                  │   ├── brain.pglite/          the database
                  │   ├── config.json            engine, embedding model, dims
                  │   └── railway/
                  │       ├── admin-bootstrap-token   mode 600
                  │       └── connect-token           mode 600
                  └── brain/                     markdown system of record (git)
```

### Why no s6-overlay

The sibling `claude-code-ssh` template uses s6-overlay because it genuinely
supervises several long-lived processes (sshd, syslog, fail2ban). This template
runs exactly one: the MCP server. A process supervisor would add a dependency
and a failure mode without supervising anything, so the entrypoint just runs
initialization and then `exec`s the server.

`tini` is still PID 1 — it reaps zombies and forwards `SIGTERM`, so Railway's
graceful shutdown reaches the server instead of being swallowed by a shell.

## Persistence

`GBRAIN_HOME` is the single lever. GBrain treats it as a *parent* directory and
appends `.gbrain` itself, so `GBRAIN_HOME=/data` puts the entire config
directory — database, config, tokens — onto the Railway volume. Nothing else
needs relocating.

The brain repo (`/data/brain`) sits alongside it. GBrain's system of record is a
plain git repo of markdown; the database is a derived index built from it.

`config.json` records `database_path` as an absolute path. Because
`GBRAIN_HOME` is fixed at `/data` in the image, that path stays valid across
redeploys and container replacements.

## Boot sequence

`scripts/init-gbrain.sh` is idempotent — every step is safe to re-run, which is
what makes redeploys uneventful.

1. **Volume.** Resolves the data directory from `RAILWAY_VOLUME_MOUNT_PATH`
   (falling back to `GBRAIN_HOME`, then `/data`) and refuses to start when that
   variable is absent on Railway. A writability check alone cannot catch this:
   with no volume the container's own filesystem is writable, so the brain would
   be created, work perfectly, and be destroyed by the next deploy. Following
   the reported mount path also means the template works wherever the operator
   attached the volume.
2. **Embedding provider.** Resolves `EMBEDDING_MODEL`, else the first of
   `OPENAI_API_KEY` / `ZEROENTROPY_API_KEY` / `VOYAGE_API_KEY`. Dies with a
   paste-ready message when none is set.
3. **Brain.** `gbrain init --pglite` on first boot; `gbrain init --migrate-only`
   afterwards. That split is what makes bumping `GBRAIN_VERSION` a safe,
   non-destructive operation.
4. **Brain repo.** Clones `BRAIN_REPO_URL` if set (pulling on later boots),
   otherwise initializes a local repo.
5. **Admin token.** Generates and persists one when `GBRAIN_ADMIN_BOOTSTRAP_TOKEN`
   isn't supplied, and validates the format when it is.
6. **Connect token.** Mints a bearer on first boot only.
7. **Timezone.** Validated against `/usr/share/zoneinfo` before being applied.
8. **Banner.** URLs, engine, version, and the one-time connect block.

## Design decisions

### Root only long enough to fix the volume

Railway mounts volumes as `root`. An image that declares `USER` up front cannot
write to its own volume, and Railway's documented workaround is to set
`RAILWAY_RUN_UID=0` — which means running a public MCP endpoint as root.

Instead the image declares no `USER`. The entrypoint starts as root, `chown`s
`/data` to uid 10001, and then `exec`s itself through `setpriv` to drop to the
unprivileged `gbrain` user. Everything after that — init, the server, every
GBrain call — runs unprivileged. The `chown` is deliberately non-fatal so a
read-only mount surfaces the clearer "not writable" diagnostic from the boot
script rather than a bare `chown` error.

### Clearing the PGLite lock on every boot

PGLite is strictly single-writer and guards its data directory with a lock file
recording the holder's PID. GBrain deliberately never reaps a lock whose PID is
still alive — stealing it from a live, slow writer corrupts the store.

That check is correct on a normal host and wrong across a container restart. The
new container gets a fresh PID namespace, so the dead holder's PID — typically a
low number like 7 — is very likely alive again as something unrelated. The lock
then looks permanently held, and both the migration pass and the server fail to
open the brain. On Railway, where every redeploy restarts the container, the
service would come up broken on the second deploy.

The boot script removes the lock before touching the brain. Any lock present at
that point is stale by construction: this container runs exactly one GBrain
process, and the script runs before it starts. Note this is only the remedy for
a *stale* lock — GBrain reports a corrupted store as a separate failure, and
deleting the lock does not fix that one.

`railway.json` also sets `drainingSeconds: 30`. Railway's default is `0`, so
`SIGTERM` is followed immediately by `SIGKILL` and GBrain never gets to release
the lock or checkpoint cleanly — which is what makes the stale lock the norm
rather than the exception. The drain window lets shutdown finish properly; the
lock clearing above stays as the backstop for a hard kill.

### Embedding provider failure is fatal, on purpose

GBrain fixes the vector column width when the brain is created. A brain created
under one provider and queried under another fails later with
`expected N dimensions, not M` — at import time, far from the cause. Refusing to
boot converts a confusing runtime failure into an obvious deploy failure.

### The connect token prints exactly once

GBrain deliberately hides generated secrets on non-TTY starts so they never land
in log storage. On Railway that would mean nobody could ever reach the brain, so
this template mints a token and prints it — but only on the boot that created
it, with a rotation hint. `GBRAIN_SKIP_CONNECT_TOKEN=1` opts out entirely:
nothing is minted, nothing is printed, and clients are registered from `/admin`.

GBrain generates token values internally (`auth create` accepts no supplied
value), so an operator-provided connect token is not possible — the escape hatch
has to be "mint nothing" rather than "use mine". The published template pairs
well with this: it generates `GBRAIN_ADMIN_BOOTSTRAP_TOKEN` via Railway's
`${{secret(...)}}` function, so `/admin` is reachable using a value that only
ever exists in the Variables tab. See
[railway-template-setup.md](railway-template-setup.md).

This is the one place the template knowingly trades a little of GBrain's log
hygiene for first-run usability. Deploy logs are visible to everyone with access
to the Railway project; rotate the token if that isn't just you.

### Pinned version, clone-based install

`GBRAIN_VERSION` pins a release tag. GBrain ships several releases a week, so
tracking `master` would make every redeploy a coin flip.

The image installs via `git clone --branch <tag>` plus `bun link` rather than
`bun install -g github:garrytan/gbrain`. Both are documented upstream; clone
resolves over plain git instead of the GitHub API tarball endpoint, which makes
the build work on networks where `api.github.com` is restricted.

GBrain is **not** on npm. The npm package of that name is unrelated and shadows
the real binary on `PATH`.

### Security updates are applied at build time

The build runs `apt-get upgrade` before installing anything. `oven/bun:1-debian`
is rebuilt on its own cadence, so between rebuilds it carries packages that
Debian has already fixed — `CVE-2026-4878`, a privilege escalation in
`libcap2`'s `cap_set_file()`, arrived that way and showed up as the repository's
only open code-scanning alert.

Hadolint's `DL3005` warns against `apt-get upgrade` because it makes a build
non-reproducible. That is a real cost, and it is the smaller one: the version
that matters for behavior is `GBRAIN_VERSION`, which is pinned, and the
distribution is pinned by the base image tag. What varies is patch level, and
varying in the direction of *patched* is the point. The rule is ignored in
`.hadolint.yaml` with that reasoning recorded.

The Trivy workflow is what catches the next one. It scans CRITICAL and HIGH with
`ignore-unfixed`, so it reports only what an upgrade could actually fix, and it
runs weekly as well as on push — newly disclosed CVEs surface without anyone
touching the repo. Its findings are written to the run summary as well as the
Security tab, so a red scan is readable from the run that produced it.

### Binding and the OAuth issuer

GBrain binds `127.0.0.1` by default, which on Railway means the edge proxy can
never reach it. The entrypoint passes `--bind 0.0.0.0`, and `--public-url` built
from `RAILWAY_PUBLIC_DOMAIN` so the OAuth issuer in discovery metadata matches
the URL clients actually hit, per RFC 8414 §3.3.

Binding `0.0.0.0` makes GBrain reject cross-origin requests to the OAuth
endpoints unless `GBRAIN_HTTP_CORS_ORIGIN` is set. Bearer-token CLI clients are
unaffected; browser-based OAuth clients (ChatGPT, Claude Desktop/Cowork) need
the allowlist. The boot banner says so rather than leaving it to be discovered.

### PGLite over Postgres

PGLite removes an entire service, a connection string, and a class of
misconfiguration, and it starts in about two seconds. The real trade-off is that
it is single-writer, so a large sync contends with the live server, and it is
sized for brains up to roughly 50K pages.

For anything larger, or to run cron enrichment concurrently with the server,
attach `DATABASE_URL` from Railway's **pgvector** template — Railway's standard
Postgres image does not ship the `vector` extension.

## Verification status

The GBrain behavior this template depends on was exercised directly against
`gbrain 0.42.73.2`: non-TTY init, `auth create` on the PGLite engine, `/health`
returning `200`, `/mcp` returning `401` unauthenticated, and the boot script's
first-run, redeploy, and failure paths.

The Docker image itself has not been built or run — no Docker daemon was
available in the environment where this was written. The image build is covered
by CI on every push.
