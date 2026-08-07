# ==============================================================================
# gbrain-hosted-agentic-memory — GBrain MCP server for Railway
# Base: oven/bun (Debian)
# PID 1: gbrain serve --http (single process; init runs first via entrypoint)
# ==============================================================================

FROM oven/bun:1-debian

# ---------- build args --------------------------------------------------------
# Pinned to a known-good GBrain release. GBrain is NOT on npm and ships several
# releases a week, so tracking master would make every redeploy a coin flip.
# Override at build time: --build-arg GBRAIN_VERSION=v0.42.74.0
ARG GBRAIN_VERSION=v0.42.73.2

# ---------- locale ------------------------------------------------------------
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# ---------- system packages ---------------------------------------------------
# git      — the brain repo is a real git repo (GBrain's system of record)
# curl     — HEALTHCHECK
# jq       — boot script parses `gbrain doctor --json`
# ca-certs — HTTPS to the embedding provider and GitHub
RUN apt-get update && apt-get install -y --no-install-recommends \
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
        https://github.com/garrytan/gbrain.git /opt/gbrain \
    && cd /opt/gbrain \
    && bun install \
    && bun link \
    && gbrain --version \
    && rm -rf /root/.bun/install/cache /opt/gbrain/.git

# Recorded so the boot banner can report what is actually running, and so
# `gbrain doctor` output can be matched against the image that produced it.
ENV GBRAIN_VERSION=${GBRAIN_VERSION}

# ---------- non-root user -----------------------------------------------------
RUN useradd -m -u 10001 -s /bin/bash gbrain \
    && mkdir -p /data \
    && chown gbrain:gbrain /data

# ---------- scripts -----------------------------------------------------------
COPY scripts/init-gbrain.sh /usr/local/bin/init-gbrain
COPY scripts/entrypoint.sh  /usr/local/bin/entrypoint
COPY banner.txt             /etc/gbrain-banner.txt
RUN chmod +x /usr/local/bin/init-gbrain /usr/local/bin/entrypoint

# ---------- runtime -----------------------------------------------------------
# GBRAIN_HOME is a PARENT directory — GBrain appends '.gbrain' itself, so this
# resolves to /data/.gbrain. Pointing it at the Railway volume is what makes
# the brain, its config, and its tokens survive redeployment.
ENV GBRAIN_HOME=/data \
    BRAIN_REPO_PATH=/data/brain \
    PORT=8080

USER gbrain
WORKDIR /data

EXPOSE 8080

# GBrain's own /health handler budgets 3s so it can answer before an
# orchestrator's 5s deadline; give it that plus framing headroom.
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1

# tini reaps zombies and forwards SIGTERM, so Railway's graceful shutdown
# reaches the server instead of being swallowed by the shell.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint"]
