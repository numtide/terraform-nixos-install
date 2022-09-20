#!/usr/bin/env bash

set -uex -o pipefail

if [ "$#" -ne 5 ]; then
  echo "USAGE: $0 NIXOS_PARTITIONER_ATTR NIXOS_SYSTEM_ATTR TARGET_HOST TARGET_PORT SSH_KEY" >&2
  exit 1
fi

NIXOS_PARTITIONER_ATTR=$1
NIXOS_SYSTEM_ATTR=$2
TARGET_HOST="$3"
TARGET_PORT="$4"
SSH_KEY="$5"
shift 5

# FIXME: Do we need to support legacy nix here?
nixos_partitioner=$(nix build --print-out-paths --builders '' "$NIXOS_PARTITIONER_ATTR")
nixos_system=$(nix build --print-out-paths --builders '' "${NIXOS_SYSTEM_ATTR}.config.system.build.toplevel")

workDir=$(mktemp -d)
trap 'rm -rf "$workDir"' EXIT

sshOpts=(-p "${TARGET_PORT}")

if [[ -n ${SSH_KEY+x} && ${SSH_KEY} != "-" ]]; then
  sshPrivateKeyFile="$workDir/ssh_key"
  echo "$SSH_KEY" >"$sshPrivateKeyFile"
  chmod 0700 "$sshPrivateKeyFile"
  sshOpts+=(-o "IdentityFile=${sshPrivateKeyFile}")
fi

nixCopy() {
  NIX_SSHOPTS="${sshOpts[*]}" nix copy --experimental-features nix-command "$@"
}

# We assume for now that it's quicker to build drvs on the target...
nixCopy --to "ssh://$TARGET_HOST" "$nixos_partitioner"
# shellcheck disable=SC2029
ssh "${sshOpts[@]}" "$TARGET_HOST" "$(printf "%q" "$nixos_partitioner")"

nixCopy --to "ssh://$TARGET_HOST?remote-store=local?root=/mnt" "$nixos_system"

# shellcheck disable=SC2029
ssh "${sshOpts[@]}" "$TARGET_HOST" "ln -sf $(printf "%q" "$nixos_system") /run/nixos-install"
