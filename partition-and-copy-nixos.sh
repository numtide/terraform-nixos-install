#!/usr/bin/env bash

set -uex -o pipefail

if [ "$#" -ne 4 ]; then
  echo "USAGE: $0 NIXOS_PARTITIONER_ATTR NIXOS_SYSTEM_ATTR TARGET_HOST TARGET_PORT SSH_KEY" >&2
  exit 1
fi

NIXOS_PARTITIONER_ATTR=$1
NIXOS_SYSTEM_ATTR=$2
TARGET_HOST="$3"
TARGET_PORT="$4"
shift 4

root=$(git rev-parse --show-toplevel)
if [ -e "$root"/flake.nix ]; then
  nixos_partitioner=$(nix build --print-out-paths --builders '' "$NIXOS_PARTITIONER_ATTR")
  nixos_system=$(nix build --print-out-paths --builders '' "${NIXOS_SYSTEM_ATTR}.config.system.build.toplevel")
elif [ -e "$root"/nix/default.nix ]; then
  nixos_partitioner=$(nix-build --builders '' "$root/nix" -A "$NIXOS_PARTITIONER_ATTR")
  nixos_system=$(nix-build --builders '' "$root/nix" -A "$NIXOS_SYSTEM_ATTR.config.system.build.toplevel")
else
  echo neither flake.nix or nix/default.nix found. bailing out
fi

workDir=$(mktemp -d)
trap 'rm -rf "$workDir"' EXIT

sshOpts=(-p "${TARGET_PORT}")
sshOpts+=(-o UserKnownHostsFile=/dev/null)
sshOpts+=(-o StrictHostKeyChecking=no)

if [[ -n ${SSH_KEY+x} && ${SSH_KEY} != "-" ]]; then
  sshPrivateKeyFile="$workDir/ssh_key"
  echo "$SSH_KEY" >"$sshPrivateKeyFile"
  chmod 0700 "$sshPrivateKeyFile"
  unset SSH_AUTH_SOCK # don't use system agent if key was supplied
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
