#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
revision=f42ef42ef6ceccb3c6a20bea2481d87949a51c81
if [[ ! -d .upstream/horizon/.git ]]; then
    mkdir -p .upstream
    git init .upstream/horizon
    git -C .upstream/horizon remote add origin https://github.com/horizon-rust/horizon.git
fi
if [[ "$(git -C .upstream/horizon rev-parse HEAD 2>/dev/null || true)" != "$revision" ]]; then
    if [[ -n "$(git -C .upstream/horizon status --porcelain)" ]]; then
        echo 'The validation checkout has local changes; keep them before updating it.' >&2
        exit 1
    fi
    git -C .upstream/horizon fetch --depth 1 origin "$revision"
    git -C .upstream/horizon checkout --detach "$revision"
fi
echo 'Horizon loader is ready. Run cargo run --release -- packs/markti dist/*.zip'
