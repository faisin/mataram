#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0
while IFS= read -r -d '' file; do
  head_line="$(head -n 1 "$file" 2>/dev/null || true)"
  [[ "$head_line" == '#!'*bash* || "$head_line" == '#!/bin/sh'* ]] || continue
  if ! bash -n "$file"; then printf 'SYNTAX ERROR: %s\n' "$file" >&2; failed=1; fi
done < <(find "$ROOT" -type f -name '*.sh' -print0)
(( failed == 0 )) || exit 1
printf 'Shell syntax OK.\n'
