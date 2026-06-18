#!/usr/bin/env bash
# Thin entrypoint: with no arguments, drop into an interactive shell (handy for
# `docker compose run pg`); otherwise exec whatever was passed (e.g. `pg login`,
# `pg deploy ...`). PATH already carries the playground bin dirs via ENV.
set -e

if [ "$#" -eq 0 ]; then
  exec bash
fi

exec "$@"
