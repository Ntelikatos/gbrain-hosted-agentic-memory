#!/bin/bash
# ==============================================================================
# entrypoint.sh — Initialize, then hand the container over to the MCP server.
# ==============================================================================
set -euo pipefail

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

# Opt-in: browser-based OAuth clients need the token TTL raised or DCR on.
if [ -n "${GBRAIN_TOKEN_TTL:-}" ]; then
    SERVE_ARGS+=(--token-ttl "${GBRAIN_TOKEN_TTL}")
fi
if [ "${GBRAIN_ENABLE_DCR:-}" = "1" ]; then
    SERVE_ARGS+=(--enable-dcr)
fi

echo ">>> Starting: gbrain ${SERVE_ARGS[*]}"

# exec so the server becomes the container's main process and receives
# SIGTERM directly on redeploy, instead of being killed after a shell.
exec gbrain "${SERVE_ARGS[@]}"
