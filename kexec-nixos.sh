#!/usr/bin/env bash

set -uex -o pipefail

if [ "$#" -ne 1 ]; then
  echo "USAGE: $0 <KEXEC_TARBALL_URL>" >&2
  exit 1
fi

URL=$1

if command -v curl >/dev/null 2>&1; then
  fetch() { curl --fail -Ss -L "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget "$1" -O-; }
else
  echo "you don't have wget or curl installed, which I need to download the binary tarball"
  exit 1
fi

rm -rf /root/kexec-installer
mkdir -p /root/kexec-installer
# Don't use `/tmp` here in case its tmpfs to prevent out-of-memory situations.
fetch "$URL" | tar -C /root/kexec-installer -xvzf-
export TMPDIR=/root/kexec-installer
setsid /root/kexec-installer/kexec/run
