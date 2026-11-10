#!/usr/bin/env bash
# Prints the components the pipeline should run, as a JSON array of
# {component, stack} objects for a job matrix.
#
#   matrix.sh all            every component with settings.ci.enabled
#   matrix.sh affected BASE  only those whose code or stack config changed since BASE
#
# A change to the pipeline itself or to atmos.yaml re-plans everything, because
# it can alter how every component is planned.
set -euo pipefail

mode="${1:?usage: matrix.sh all | affected BASE}"
base="${2:-}"

all() {
  atmos describe stacks --format json | jq -c '
    [ to_entries[]
      | .key as $stack
      | (.value.components.terraform // {})
      | to_entries[]
      | select(.value.settings.ci.enabled == true)
      | { component: .key, stack: $stack } ]'
}

if [ "${mode}" = "affected" ]; then
  if git diff --name-only "${base}...HEAD" | grep -qE '^(\.github/|atmos\.yaml$)'; then
    all
  else
    # describe affected does not return settings, so intersect with the enabled list.
    atmos describe affected --base "${base}" --format json \
      | jq -c --argjson enabled "$(all)" '
          [ .[] | { component, stack } ] | unique | map(select(. as $c | $enabled | index($c)))'
  fi
else
  all
fi
