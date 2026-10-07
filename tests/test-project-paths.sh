#!/bin/bash
# Run inside the profiling-aware test suite; no host package/VM operations.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/tools/pve-microvm-env.sh"
pve_microvm_env tests
for path in "$TMPDIR" "$TMP" "$TEMP" "$XDG_CACHE_HOME" "$BUN_INSTALL_CACHE_DIR" "$npm_config_cache" "$PYTHONPYCACHEPREFIX"; do
    [[ "$path" = "$PVE_MICROVM_TMP_ROOT/"* && -d "$path" ]]
done
[ "$PVE_MICROVM_KERNEL_DIR" = "$PVE_MICROVM_TMP_ROOT/build/kernel" ]
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
# Reject an inherited run outside the owned tree before consumers can use it.
if PVE_MICROVM_RUN_DIR=/tmp bash "$ROOT/tools/pve-microvm-env.sh" --exec tests true; then
    echo 'unowned run unexpectedly accepted' >&2; exit 1
fi
if PROJECT_TMP_ROOT=/tmp PVE_MICROVM_TMP_ROOT=/tmp PVE_MICROVM_RUN_DIR= bash "$ROOT/tools/pve-microvm-env.sh" --exec tests true; then
    echo 'unowned root unexpectedly accepted' >&2; exit 1
fi
# A documented hosted-runner/remote mapping keeps identical child layout.
env -u PROJECT_TMP_BASE -u PVE_MICROVM_TMP_ROOT PROJECT_TMP_ROOT="$fixture/runner/pve-microvm" PVE_MICROVM_KERNEL_DIR= PVE_MICROVM_RUN_DIR= \
    bash "$ROOT/tools/pve-microvm-env.sh" --exec tests bash -c '
        [[ "$TMPDIR" = "$PVE_MICROVM_TMP_ROOT/runs/tests/"* ]]
        [[ "$XDG_CACHE_HOME" = "$PVE_MICROVM_TMP_ROOT/cache/xdg" ]]
        [[ "$PVE_MICROVM_BUILD_DIR" = "$PVE_MICROVM_TMP_ROOT/build" ]]
    '
# Never expose host absolute scratch paths to guest package scripts.
printf '#!/bin/bash\ntest "$TMPDIR" = /tmp && test "$TMP" = /tmp && test "$TEMP" = /tmp\ntest -z "${PROJECT_TMP_ROOT+x}" && test -z "${PYTHONPYCACHEPREFIX+x}" && test -z "${XDG_CACHE_HOME+x}"\n' > "$fixture/chroot"
chmod +x "$fixture/chroot"
PATH="$fixture:$PATH" pve_microvm_chroot ignored-root ignored-command

# Fallback order: CI ignores a usable workspace; local ignores runner temp.
source "$ROOT/tools/lib/project-tmp.sh"
unset PROJECT_TMP_ROOT PROJECT_TMP_BASE
mkdir -p "$fixture/runner" "$fixture/original" "$fixture/workspace"
RUNNER_TEMP="$fixture/runner" PROJECT_ORIGINAL_TMPDIR="$fixture/original"
CI=true
[ "$(project_tmp_resolve pve-microvm "$fixture/workspace")" = "$fixture/runner/pve-microvm" ]
unset RUNNER_TEMP
[ "$(project_tmp_resolve pve-microvm "$fixture/workspace")" = "$fixture/original/pve-microvm" ]
CI=false GITHUB_ACTIONS=false GITLAB_CI=false TF_BUILD=false CIRCLECI=false
[ "$(project_tmp_resolve pve-microvm "$fixture/workspace")" = "$fixture/workspace/pve-microvm" ]
[ "$(PROJECT_TMP_BASE="$fixture/base" project_tmp_resolve pve-microvm)" = "$fixture/base/pve-microvm" ]
[ "$(PROJECT_TMP_BASE="$fixture/base" PROJECT_TMP_ROOT="$fixture/base/pve-microvm" project_tmp_resolve pve-microvm)" = "$fixture/base/pve-microvm" ]
if PROJECT_TMP_BASE="$fixture/base" PROJECT_TMP_ROOT="$fixture/other/pve-microvm" project_tmp_resolve pve-microvm; then
    echo 'conflicting override accepted' >&2; exit 1
fi
if PROJECT_TMP_BASE=relative project_tmp_resolve pve-microvm; then
    echo 'relative base accepted' >&2; exit 1
fi
# A project root symlink is never a valid override.
ln -s "$fixture/original" "$fixture/pve-microvm"
if PROJECT_TMP_ROOT="$fixture/pve-microvm" project_tmp_resolve pve-microvm; then
    echo 'symlink root unexpectedly accepted' >&2; exit 1
fi
# Defaults must not add caches or binaries to the checkout.
! grep -Eq '/tmp/pve-microvm-kernel-build|/var/cache/pve-microvm' "$ROOT/kernel/build-kernel.sh" "$ROOT/tools/pve-microvm-template"
! grep -q 'mktemp -d /tmp/' "$ROOT/tools/pve-oci-import"
echo 'project path isolation and external mapping passed'
