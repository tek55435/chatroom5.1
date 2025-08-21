#!/bin/sh
set -e
: ${ENTRY_FILE:=index.js}
echo "Starting Node service with ENTRY_FILE=$ENTRY_FILE on PORT=${PORT:-8080}"
exec node "$ENTRY_FILE"
