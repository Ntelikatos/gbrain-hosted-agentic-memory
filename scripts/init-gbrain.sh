#!/bin/bash
# ==============================================================================
# init-gbrain.sh — One-shot initialization for the GBrain Railway container.
# Runs from the entrypoint before `gbrain serve --http` takes over as PID 1.
# Idempotent: safe to run on every container restart.
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log()  { echo ">>> $*"; }
warn() { echo "!!! WARNING: $*" >&2; }
die()  { echo "!!! ERROR: $*" >&2; exit 1; }

DATA_DIR="${GBRAIN_HOME:-/data}"
GBRAIN_DIR="${DATA_DIR}/.gbrain"
BRAIN_REPO_PATH="${BRAIN_REPO_PATH:-${DATA_DIR}/brain}"
STATE_DIR="${GBRAIN_DIR}/railway"

# ==============================================================================
# Step 1: Volume directories
# ==============================================================================
log "Initializing volume directories under ${DATA_DIR}..."

if [ ! -w "${DATA_DIR}" ]; then
    die "${DATA_DIR} is not writable. Attach a Railway volume with mount path ${DATA_DIR}
    (Railway dashboard > right-click the canvas > Add Volume > mount path ${DATA_DIR}).
    Without it the brain is rebuilt empty on every deploy."
fi

mkdir -p "${GBRAIN_DIR}" "${BRAIN_REPO_PATH}" "${STATE_DIR}"
chmod 700 "${STATE_DIR}"

# ==============================================================================
# Step 2: Resolve the embedding provider
#
# GBrain exits 1 in a non-TTY when it cannot resolve a provider, by design:
# the alternative is a silent dimension mismatch between the configured
# provider and the vector column, which only surfaces later as a confusing
# `expected N dimensions, not M` on the first import. Fail loud here instead.
# ==============================================================================
log "Resolving embedding provider..."

EMBEDDING_ARGS=()
if [ -n "${EMBEDDING_MODEL:-}" ]; then
    log "  Using EMBEDDING_MODEL override: ${EMBEDDING_MODEL}"
    EMBEDDING_ARGS=(--embedding-model "${EMBEDDING_MODEL}")
elif [ -n "${OPENAI_API_KEY:-}" ]; then
    log "  Detected OPENAI_API_KEY -> openai:text-embedding-3-large (1536d)"
    EMBEDDING_ARGS=(--embedding-model "openai:text-embedding-3-large")
elif [ -n "${ZEROENTROPY_API_KEY:-}" ]; then
    log "  Detected ZEROENTROPY_API_KEY -> zeroentropyai:zembed-1 (2560d)"
    EMBEDDING_ARGS=(--embedding-model "zeroentropyai:zembed-1")
elif [ -n "${VOYAGE_API_KEY:-}" ]; then
    log "  Detected VOYAGE_API_KEY -> voyage:voyage-3-large (1024d)"
    EMBEDDING_ARGS=(--embedding-model "voyage:voyage-3-large")
else
    die "No embedding provider configured. Add ONE of these Railway variables:

      OPENAI_API_KEY=sk-...        (recommended; openai:text-embedding-3-large)
      ZEROENTROPY_API_KEY=ze-...   (GBrain's own default; zembed-1)
      VOYAGE_API_KEY=pa-...        (voyage-3-large)

    Or set EMBEDDING_MODEL=<provider>:<model> to pick explicitly.
    Search cannot work without embeddings, so startup stops here."
fi

# ==============================================================================
# Step 3: Create or migrate the brain
#
# First boot creates a PGLite brain on the volume (~2s, no database server).
# Later boots only run migrations, which is what makes bumping GBRAIN_VERSION
# in the image a safe, non-destructive operation.
# ==============================================================================
# PGLite is strictly single-writer and guards the data directory with a lock
# recording the holder's PID. GBrain refuses to reap a lock whose PID is still
# alive — correct on a normal host, wrong across a container restart: the new
# container gets a fresh PID namespace, so the dead holder's PID (typically a
# low number like 7) is very likely live again as something unrelated. The lock
# then looks held forever and BOTH the migration pass and the server fail to
# open the brain.
#
# Any lock present at this point is stale by construction: this container runs
# exactly one GBrain process, and this script runs before it starts. Removing a
# lock is the documented remedy for a stale holder — it is explicitly NOT a fix
# for a corrupted store, which is a different failure GBrain reports separately.
PGLITE_LOCK="${GBRAIN_DIR}/brain.pglite/.gbrain-lock"
if [ -e "${PGLITE_LOCK}" ]; then
    log "Clearing a PGLite lock left by a previous container life..."
    rm -rf "${PGLITE_LOCK}"
fi

if [ -f "${GBRAIN_DIR}/config.json" ]; then
    log "Existing brain found. Applying any pending schema migrations..."
    gbrain init --migrate-only --non-interactive \
        || warn "Migration pass reported an error; continuing to serve. Run 'gbrain doctor' to inspect."
else
    log "No brain found. Creating a PGLite brain at ${GBRAIN_DIR}/brain.pglite..."
    gbrain init --pglite --non-interactive "${EMBEDDING_ARGS[@]}" \
        || die "gbrain init failed. Check that your embedding provider key is valid."
    log "  Brain created."
fi

# ==============================================================================
# Step 4: Brain repo (GBrain's system of record)
#
# Knowledge lives as markdown in a git repo. Default is a local repo on the
# volume; set BRAIN_REPO_URL to back it with GitHub so the brain is portable
# and readable from your laptop.
# ==============================================================================
log "Configuring brain repo at ${BRAIN_REPO_PATH}..."

if [ -n "${BRAIN_REPO_URL:-}" ]; then
    # Token is injected via git config rather than baked into the remote URL,
    # so it never lands in .git/config's remote entry or in `git remote -v`.
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        git config --global "url.https://oauth2:${GITHUB_TOKEN}@github.com/.insteadOf" \
            "https://github.com/"
    fi

    if [ -d "${BRAIN_REPO_PATH}/.git" ]; then
        log "  Repo already cloned. Pulling latest..."
        git -C "${BRAIN_REPO_PATH}" pull --ff-only \
            || warn "Pull failed (diverged history or no network). Serving the local copy."
    else
        log "  Cloning ${BRAIN_REPO_URL}..."
        # Clone into a temp path and move contents in: BRAIN_REPO_PATH already
        # exists (created in Step 1), and `git clone` refuses a non-empty dir.
        rm -rf "${BRAIN_REPO_PATH}.tmp"
        if git clone "${BRAIN_REPO_URL}" "${BRAIN_REPO_PATH}.tmp"; then
            rm -rf "${BRAIN_REPO_PATH}"
            mv "${BRAIN_REPO_PATH}.tmp" "${BRAIN_REPO_PATH}"
            log "  Cloned."
        else
            rm -rf "${BRAIN_REPO_PATH}.tmp"
            warn "Clone failed. Check BRAIN_REPO_URL and GITHUB_TOKEN. Falling back to a local repo."
            git -C "${BRAIN_REPO_PATH}" init -q 2>/dev/null || true
        fi
    fi
elif [ ! -d "${BRAIN_REPO_PATH}/.git" ]; then
    log "  No BRAIN_REPO_URL set. Initializing a local brain repo."
    git -C "${BRAIN_REPO_PATH}" init -q
fi

# Identity is required before GBrain can commit anything into the brain repo.
git config --global --get user.email >/dev/null 2>&1 \
    || git config --global user.email "${GIT_AUTHOR_EMAIL:-gbrain@railway.local}"
git config --global --get user.name >/dev/null 2>&1 \
    || git config --global user.name "${GIT_AUTHOR_NAME:-GBrain}"
git config --global --add safe.directory "${BRAIN_REPO_PATH}" 2>/dev/null || true

# ==============================================================================
# Step 5: Admin bootstrap token
#
# On a non-TTY start GBrain hides the generated admin token so it never lands
# in log storage — which on Railway would mean nobody can ever reach /admin.
# Generate one ourselves, persist it to the volume (mode 600), and keep it
# stable across restarts.
# ==============================================================================
ADMIN_TOKEN_FILE="${STATE_DIR}/admin-bootstrap-token"

if [ -n "${GBRAIN_ADMIN_BOOTSTRAP_TOKEN:-}" ]; then
    # GBrain requires >=32 chars matching [A-Za-z0-9_-]+ and rejects anything
    # else at startup; catch it here with a useful message instead.
    if ! printf '%s' "${GBRAIN_ADMIN_BOOTSTRAP_TOKEN}" | grep -qE '^[A-Za-z0-9_-]{32,}$'; then
        die "GBRAIN_ADMIN_BOOTSTRAP_TOKEN must be at least 32 characters and contain
    only letters, digits, hyphen and underscore. Generate one with:
      openssl rand -hex 32"
    fi
    log "Admin bootstrap token: using the value from GBRAIN_ADMIN_BOOTSTRAP_TOKEN."
    ADMIN_TOKEN_SOURCE="railway-variable"
else
    if [ ! -s "${ADMIN_TOKEN_FILE}" ]; then
        log "Admin bootstrap token: generating one and persisting it to the volume."
        gbrain_generate_token() {
            if command -v openssl >/dev/null 2>&1; then
                openssl rand -hex 32
            else
                head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
            fi
        }
        umask 077
        gbrain_generate_token > "${ADMIN_TOKEN_FILE}"
    fi
    chmod 600 "${ADMIN_TOKEN_FILE}"
    GBRAIN_ADMIN_BOOTSTRAP_TOKEN="$(cat "${ADMIN_TOKEN_FILE}")"
    export GBRAIN_ADMIN_BOOTSTRAP_TOKEN
    ADMIN_TOKEN_SOURCE="generated"
fi

# ==============================================================================
# Step 6: Connect token
#
# Mint a bearer token on first boot so connecting a client is a single
# copy-paste. GBrain hides secrets from non-TTY logs on purpose, so this
# prints ONCE, on the boot that created it, and never again.
# ==============================================================================
CONNECT_TOKEN_FILE="${STATE_DIR}/connect-token"
PRINT_CONNECT_TOKEN=0

if [ -n "${GBRAIN_CONNECT_TOKEN:-}" ]; then
    # Operator supplied their own; nothing is minted and nothing is printed.
    log "Connect token: using the value from GBRAIN_CONNECT_TOKEN (nothing printed)."
    CONNECT_TOKEN="${GBRAIN_CONNECT_TOKEN}"
elif [ -s "${CONNECT_TOKEN_FILE}" ]; then
    log "Connect token: already provisioned (not reprinted; see README to rotate)."
    CONNECT_TOKEN="$(cat "${CONNECT_TOKEN_FILE}")"
else
    log "Connect token: minting one for this brain..."
    umask 077
    # `gbrain auth create` prints the token once, on stdout, as gbrain_<hex>.
    if MINT_OUTPUT="$(gbrain auth create railway 2>&1)"; then
        CONNECT_TOKEN="$(printf '%s' "${MINT_OUTPUT}" | grep -oE 'gbrain_[a-f0-9]+' | head -n1)"
        if [ -n "${CONNECT_TOKEN}" ]; then
            printf '%s\n' "${CONNECT_TOKEN}" > "${CONNECT_TOKEN_FILE}"
            chmod 600 "${CONNECT_TOKEN_FILE}"
            PRINT_CONNECT_TOKEN=1
        else
            warn "Could not parse the minted token. Create one later with: gbrain auth create <name>"
            CONNECT_TOKEN=""
        fi
    else
        warn "Token mint failed. Create one later with: gbrain auth create <name>"
        CONNECT_TOKEN=""
    fi
fi

# ==============================================================================
# Step 7: Timezone
# ==============================================================================
if [ -n "${TZ:-}" ]; then
    if printf '%s' "${TZ}" | grep -qE '^[a-zA-Z0-9/_+-]+$' \
        && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
        log "Timezone set to ${TZ}."
    else
        warn "Invalid timezone '${TZ}'. Keeping UTC."
        unset TZ
    fi
fi

# ==============================================================================
# Step 8: Startup banner
# ==============================================================================
PUBLIC_HOST="${RAILWAY_PUBLIC_DOMAIN:-}"
if [ -n "${PUBLIC_HOST}" ]; then
    PUBLIC_URL="https://${PUBLIC_HOST}"
else
    PUBLIC_URL=""
fi

[ -f /etc/gbrain-banner.txt ] && cat /etc/gbrain-banner.txt

echo
echo "----------------------------------------------------------------------"
echo "  GBrain ${GBRAIN_VERSION:-unknown}  |  engine: pglite  |  data: ${DATA_DIR}"
if [ -n "${PUBLIC_URL}" ]; then
    echo "  MCP endpoint : ${PUBLIC_URL}/mcp"
    echo "  Admin        : ${PUBLIC_URL}/admin"
    echo "  Health       : ${PUBLIC_URL}/health"
else
    echo "  No public domain yet. Railway > Settings > Networking >"
    echo "  Generate Domain, then redeploy so OAuth discovery advertises it."
fi
echo "  Admin token  : ${ADMIN_TOKEN_SOURCE} (see README to retrieve it)"
echo "----------------------------------------------------------------------"

if [ "${PRINT_CONNECT_TOKEN}" = "1" ] && [ -n "${CONNECT_TOKEN}" ]; then
    echo
    echo "======================================================================"
    echo "  CONNECT YOUR AGENT — this token is shown ONCE, right now."
    echo "======================================================================"
    if [ -n "${PUBLIC_URL}" ]; then
        echo "  gbrain connect ${PUBLIC_URL}/mcp \\"
        echo "      --token ${CONNECT_TOKEN} --install"
    else
        echo "  Token: ${CONNECT_TOKEN}"
        echo "  (generate a public domain, then run:"
        echo "   gbrain connect https://<your-domain>/mcp --token <token> --install)"
    fi
    echo
    echo "  Deploy logs are readable by anyone with access to this Railway"
    echo "  project. If that is not just you, rotate it now:"
    echo "    gbrain auth revoke railway && gbrain auth create <name>"
    echo "======================================================================"
    echo
fi

if [ -z "${GBRAIN_HTTP_CORS_ORIGIN:-}" ]; then
    echo "NOTE: GBRAIN_HTTP_CORS_ORIGIN is unset, so the OAuth endpoints reject"
    echo "      cross-origin browser requests. Bearer-token clients (Claude Code,"
    echo "      Codex, Cursor) are unaffected. Browser OAuth clients (ChatGPT,"
    echo "      Claude Desktop/Cowork) need it set — see the README."
    echo
fi

log "Initialization complete."
