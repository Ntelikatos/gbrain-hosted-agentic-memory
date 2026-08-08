#!/bin/bash
# ==============================================================================
# entrypoint.sh — Drop privileges, initialize, then hand the container over to
# the MCP server.
# ==============================================================================
set -euo pipefail

GBRAIN_UID=10001

# Railway sets RAILWAY_VOLUME_MOUNT_PATH when a volume is attached; follow it so
# ownership is fixed on the directory that actually holds the brain. Exported so
# init-gbrain.sh and the server agree on one location. init-gbrain.sh resolves
# this identically, and re-raises a missing volume as a hard error.
DATA_DIR="${RAILWAY_VOLUME_MOUNT_PATH:-${GBRAIN_HOME:-/data}}"
export GBRAIN_HOME="${DATA_DIR}"

# ------------------------------------------------------------------------------
# Privilege drop
#
# Railway mounts volumes as root. An image that declares `USER` up front cannot
# write into that volume at all, and Railway's documented workaround is to set
# RAILWAY_RUN_UID=0 and run everything as root. Instead: start as root, take
# ownership of the volume, then drop to the unprivileged `gbrain` user before
# any GBrain code runs. Same convenience, without serving a public MCP endpoint
# as root.
# ------------------------------------------------------------------------------
if [ "$(id -u)" = "0" ]; then
    if [ -d "${DATA_DIR}" ] && [ "$(stat -c '%u' "${DATA_DIR}")" != "${GBRAIN_UID}" ]; then
        echo ">>> Taking ownership of ${DATA_DIR} for uid ${GBRAIN_UID}..."
        # Non-fatal: a read-only mount fails here, and the clearer
        # "not writable" diagnostic in init-gbrain.sh should be what the
        # operator sees rather than a bare chown error.
        chown -R "${GBRAIN_UID}:${GBRAIN_UID}" "${DATA_DIR}" 2>/dev/null \
            || echo "!!! WARNING: could not chown ${DATA_DIR}; continuing." >&2
    fi
    exec setpriv --reuid="${GBRAIN_UID}" --regid="${GBRAIN_UID}" --init-groups "$0" "$@"
fi

/usr/local/bin/init-gbrain

# Railway injects PORT. Bind 0.0.0.0 so the edge proxy can reach us: GBrain
# defaults to 127.0.0.1, which would make the service look permanently down.
SERVE_ARGS=(
    serve --http
    --port "${PORT:-8080}"
    --bind 0.0.0.0
)

# --public-url sets the OAuth issuer in discovery metadata. RFC 8414 requires
# it to match the URL clients actually hit, so it must be the Railway domain
# rather than localhost. Omitted (with a warning from GBrain) until a domain
# exists, so the service still boots and stays inspectable before then.
if [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
    SERVE_ARGS+=(--public-url "https://${RAILWAY_PUBLIC_DOMAIN}")
fi

if [ -n "${GBRAIN_TOKEN_TTL:-}" ]; then
    SERVE_ARGS+=(--token-ttl "${GBRAIN_TOKEN_TTL}")
fi
if [ "${GBRAIN_ENABLE_DCR:-}" = "1" ]; then
    SERVE_ARGS+=(--enable-dcr)
fi

echo ">>> Starting: gbrain ${SERVE_ARGS[*]}"

# exec so the server becomes the container's main process and receives
# SIGTERM directly on redeploy, instead of being killed after a shell.
#
# 2>&1 merges the server's stderr into stdout. Railway derives log severity
# from the stream, and GBrain writes its normal startup banner -- the ASCII
# box, "Skills: published", the upgrade notice -- to stderr. Left alone, a
# perfectly healthy boot renders as a wall of red `error` lines and reads
# like a crash.
#
# The trade-off is real: genuine runtime errors from the server lose their
# severity too. Accepted because a deploy that fails still fails visibly via
# exit code and the healthcheck, whereas a successful deploy that *looks*
# failed sends people debugging something that is not broken. Note this
# applies only to the server: init-gbrain.sh keeps its own stderr, so its
# warnings and hard refusals are still flagged as errors.
exec gbrain "${SERVE_ARGS[@]}" 2>&1
