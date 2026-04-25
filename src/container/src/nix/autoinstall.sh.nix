{ vars }:
''
set -euo pipefail

bootstrap_url="${vars.bootstrapUrl}"

clone_flake() {
     if [[ "''${anonymous_flake_url}" == git+* ]]
     then
          nix --extra-experimental-features 'nix-command flakes' flake clone "''${anonymous_flake_url}" \
            --dest /mnt/opt/config
     else
          mkdir -p /mnt/opt/config

          curl -fL "''${anonymous_flake_url}" | tar -xz -C /mnt/opt/config --strip-components=1
     fi

     git -C /mnt/opt/config remote set-url origin "''${flake_url:-''${anonymous_flake_url}}"
}

fetch_info() {
     curl -fsSL "''${bootstrap_url}"
}

get_field() {
     local field="$1"
     local value=$(echo "''${bootstrap}" | jq -r ".$field // empty")

     if [[ -z "''${value}" ]]
     then
          echo "Error: missing required field ''${field} in bootstrap configuration" >&2

          exit 1
     fi

     echo "$value"
}

get_optional_field() {
     local field="$1"

     echo "''${bootstrap}" | jq -r ".$field // empty"
}

# Get bootstrap information.
until bootstrap=$(fetch_info)
do
     echo "Waiting for bootstrap file located at ''${bootstrap_url}..."

     sleep 5
done

age_present=$(get_optional_field "age")
anonymous_flake_url=$(get_field "anonymousFlakeUrl")
disk=$(get_field "disk")
flake_path=$(get_optional_field "flakePath")
flake_url=$(get_optional_field "flakeUrl")
flake_host=$(get_field "host")

if [[ -n "''${age_present}" ]]
then
     age_private_key=$(echo "''${bootstrap}" | jq -r ".age.privateKey // empty")
     age_install_path=/mnt/$(echo "''${bootstrap}" | jq -r ".age.installPath // empty")

     if [[ -z "''${age_private_key}" ]]
     then
          echo "Error: missing required field age.privateKey in bootstrap configuration" >&2

          exit 1
     fi

     if [[ -z "''${age_install_path}" ]]
     then
          echo "Error: missing required field age.installPath in bootstrap configuration" >&2

          exit 1
     fi
fi

# Partition disk.
parted -s "''${disk}" -- mklabel gpt
parted -s "''${disk}" -- mkpart ESP fat32 1MiB 512MiB
parted -s "''${disk}" -- set 1 esp on
parted -s "''${disk}" -- mkpart primary ext4 512MiB 100%

mkfs.fat -F 32 -n BOOT "''${disk}1"
mkfs.ext4 -F -L nixos "''${disk}2"

mount "''${disk}2" /mnt
mkdir -p /mnt/boot
mount "''${disk}1" /mnt/boot

until clone_flake
do
     echo "Waiting for flake located at ''${anonymous_flake_url}..."

     rm -rf /mnt/opt/config

     sleep 5
done

nixos-generate-config --root /mnt
cp /mnt/etc/nixos/hardware-configuration.nix /etc/nixos/hardware-configuration.nix

# Add age private key.
age_present=$(get_optional_field "age")

if [[ -n "''${age_present}" ]]
then
     mkdir -p "$(dirname "''${age_install_path}")"
     printf '%s' "''${age_private_key}" > "''${age_install_path}"
     chmod 400 "''${age_install_path}"
fi

# Install NixOS.
export PATH="$PATH:/nix/var/nix/profiles/system/sw/bin"

nixos-install --flake /mnt/opt/config/"''${flake_path}"#"''${flake_host}" --no-root-passwd --impure
nix store gc --extra-experimental-features nix-command --store /mnt

systemctl --no-block reboot
''
