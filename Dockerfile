# ==============================================================================
# gbrain-hosted-agentic-memory — GBrain MCP server for Railway
# Base: oven/bun (Debian)
# PID 1: tini -> entrypoint -> (init, drop privileges) -> gbrain serve --http
# ==============================================================================

FROM oven/bun:1-debian

# ---------- build args --------------------------------------------------------
# Pinned to a known-good GBrain release. GBrain is NOT on npm and ships several
# releases a week, so tracking master would make every redeploy a coin flip.
# Override at build time: --build-arg GBRAIN_VERSION=v0.42.75.0
ARG GBRAIN_VERSION=v0.42.74.0

# ---------- locale ------------------------------------------------------------
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ---------- system packages ---------------------------------------------------
# git      — the brain repo is a real git repo (GBrain's system of record)
# curl     — HEALTHCHECK
# jq       — boot script parses `gbrain doctor --json`
# ca-certs — HTTPS to the embedding provider and GitHub
#
# `apt-get upgrade` applies the security updates Debian has published since the
# base image was last rebuilt. Without it the image inherits whatever was fixed
# upstream but not yet rolled into `oven/bun:1-debian` — which is exactly how
# CVE-2026-4878 (libcap2 privilege escalation) reached the scanner. Hadolint
# warns against this for reproducibility; that trade is made deliberately here,
# see .hadolint.yaml.
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
        git \
        curl \
        jq \
        ca-certificates \
        locales \
        tini \
    && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# ---------- GBrain ------------------------------------------------------------
# Installed via the clone + `bun link` path that GBrain documents alongside
# `bun install -g github:garrytan/gbrain`. Both are supported upstream; clone
# is used here because it resolves over plain git rather than the GitHub API
# tarball endpoint, and `--branch <tag>` pins the exact release without
# depending on api.github.com being reachable from the builder.
#
# NOTE: GBrain is NOT distributed on npm. The npm package named `gbrain` is an
# unrelated project and will shadow the real binary on PATH. Never add it here.
ENV BUN_INSTALL=/usr/local/bun
ENV PATH=/usr/local/bun/bin:$PATH

RUN git clone --depth 1 --branch "${GBRAIN_VERSION}" \
        https://github.com/garrytan/gbrain.git /opt/gbrain

WORKDIR /opt/gbrain
RUN bun install \
    && bun link \
    && gbrain --version \
    && rm -rf /root/.bun/install/cache /opt/gbrain/.git

# Recorded so the boot banner can report what is actually running, and so
# `gbrain doctor` output can be matched against the image that produced it.
ENV GBRAIN_VERSION=${GBRAIN_VERSION}

# ---------- unprivileged user -------------------------------------------------
# Deliberately NO `USER gbrain` instruction. Railway mounts volumes as root, so
# a container that starts as a non-root UID cannot write to its own volume.
# entrypoint.sh starts as root, takes ownership of /data, then drops to this
# user via setpriv before any GBrain code runs — so the server still runs
# unprivileged without needing Railway's RAILWAY_RUN_UID=0 workaround.
RUN useradd -m -u 10001 -s /bin/bash gbrain \
    && mkdir -p /data \
    && chown gbrain:gbrain /data /home/gbrain

# ---------- scripts -----------------------------------------------------------
COPY scripts/init-gbrain.sh /usr/local/bin/init-gbrain
COPY scripts/entrypoint.sh  /usr/local/bin/entrypoint
COPY banner.txt             /etc/gbrain-banner.txt
RUN chmod +x /usr/local/bin/init-gbrain /usr/local/bin/entrypoint

# ---------- runtime -----------------------------------------------------------
# GBRAIN_HOME is a PARENT directory — GBrain appends '.gbrain' itself, so this
# resolves to /data/.gbrain. Pointing it at the Railway volume is what makes
# the brain, its config, and its tokens survive redeployment.
# BRAIN_REPO_PATH is deliberately NOT set here: the boot script derives it from
# the resolved data directory, so it follows the Railway volume's actual mount
# path. Set it as a service variable only to override that.
ENV GBRAIN_HOME=/data \
    HOME=/home/gbrain \
    PORT=8080

WORKDIR /data

EXPOSE 8080

# GBrain's own /health handler budgets 3s so it can answer before an
# orchestrator's 5s deadline; give it that plus framing headroom.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1

# tini reaps zombies and forwards SIGTERM, so Railway's graceful shutdown
# reaches the server instead of being swallowed by the shell.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
