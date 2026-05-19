#!/bin/bash

set -euo pipefail

if [ -s "$HOME/.nvm/nvm.sh" ]; then
  . "$HOME/.nvm/nvm.sh"
  nvm use 22 >/dev/null
fi

if [ "$#" -gt 0 ]; then
  npx artillery "$@"
else
  npx artillery run loadtest/load-test.yml
fi
