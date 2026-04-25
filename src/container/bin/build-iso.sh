#!/usr/bin/env bash

set -euo pipefail

usage() {
     cat <<EOF
Usage: $(basename "$0") --bootstrap-url url --output-file file

Build an unattended NixOS installation ISO.

Required arguments:
  -b, --bootstrap-url url    URL where install boostrap information is located
  -o, --output-file file     Output ISO filename

Optional arguments:
  -s, --system       Nix system string (e.g., aarch64-linux, x86_64-linux), defaults to current system
  -h, --help         Show this help message

Example:
  $(basename "$0") --bootstrap-url http://192.168.1.100:8000/bootstrap.json --output-file nixos.iso --system x86_64-linux
EOF

     exit 1
}

opts=$(getopt -o 'b:o:s:h' --long 'bootstrap-url:,output-file:,system:,help' -n "$(basename "$0")" -- "$@") || usage

eval set -- "$opts"

bootstrap_url=
output_file=
system=

while true
do
     case "$1" in
          -b|--bootstrap-url) bootstrap_url="$2"; shift 2 ;;
          -o|--output-file) output_file="$2"; shift 2 ;;
          -s|--system) system="$2"; shift 2 ;;
          -h|--help) usage ;;
          --) shift; break ;;
     esac
done

if [[ -z "${bootstrap_url}" ]]
then
     echo "Error: --bootstrap-url is required"

     usage
fi

if [[ -z "${output_file}" ]]
then
     echo "Error: --output-file is required"

     usage
fi

echo "Building unattended NixOS installation ISO..."
echo "  Bootstrap URL:  ${bootstrap_url}"
[[ -n "${system}" ]] && echo "  System:         ${system}"

system_arg=()
[[ -n "${system}" ]] && system_arg=(--system "${system}")

INSTALL_BOOTSTRAP_URL="${bootstrap_url}" nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage \
  -I nixos-config=/opt/container/src/nix/iso.nix "${system_arg[@]}"

mv result/iso/*.iso "/output/${output_file}"
