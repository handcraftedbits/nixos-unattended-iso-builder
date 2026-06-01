# nixos-unattended-iso-builder

A [Docker](https://www.docker.com/) image used to create a fully unattended [NixOS](https://nixos.org/) installation
ISO image.

# Notes

The built ISO image makes several key assumptions about the nature of the NixOS installation:

* The system can be built using a single [Nix flake](https://wiki.nixos.org/wiki/Flakes).
  * This flake is hosted in a Git repository or as a tarball available on an HTTP server.
  * Cloning the flake to `/opt/config` is acceptable.
* The system can access a web server during installation to fetch bootstrapping information.
* Using impure derivations during `nixos-rebuild` is acceptable.

# Usage

## Bootstrapping

Create a JSON file that contains bootstrapping information:

```json
{
  "age": {
    "installPath": "/etc/age-key",
    "privateKey": "<REDACTED>"
  },
  "anonymousFlakeUrl": "git+https://github.com/...",
  "disk": "/dev/sda",
  "flakeUrl": "git@github.com:...",
  "host": "hostname"
}
```

This JSON object contains the following fields:

* `age` (optional)

  The private key used to decrypt [age](https://age-encryption.org)-encrypted secrets via
  [agenix](https://github.com/ryantm/agenix)
  * `installPath` (required)

    The location where the private key will be saved on the installed system. The file will be owned by `root` with
    `u+r` permissions.
  * `privateKey` (required)
    The contents of the age private key.
* `anonymousFlakeUrl` (required)

  The URL where the flake can be cloned or fetched. This URL must follow the
  [Nix flake reference URL-like syntax](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake.html#examples).
* `disk` (required)

  The device name of the disk where the system will be installed. The entire disk will be used.
* `flakeUrl` (optional)

  The Git repository URL for the flake that _requires_ authentication. The typical use case is to switch the Git 
  repository to use SSH for authentication, which is not possible during installation.
* `host` (required)

  The hostname of the system.

## Building the ISO Image

Build the ISO using [Docker](https://www.docker.com/), [Podman](https://podman.io/), or a similarly-compatible container
runtime:

```shell
docker run --rm -v "/tmp:/output" ghcr.io/handcraftedbits/nixos-unattended-iso-builder:latest \
  --bootstrap-url http://10.0.0.2:8080/bootstrap.json \
  --output-file nixos.iso \
  --system x86_64-linux
```

The following arguments are supported:

* `-b`, `--bootstrap-url` (required)

  The URL where the bootstrapping information can be fetched during installation. 

* `-o`, `--output-file` (required)

  The filename for the built ISO image.

* `-s`, `--system` (optional)

  The name of the NixOS [system architecture identifier](https://raw.githubusercontent.com/NixOS/nixpkgs/refs/heads/master/lib/systems/doubles.nix)
  for the ISO. Note that not all values may be valid. Common values are `aarch64-linux` and `x86_64-linux`. If not
  specified, the default value will match the system where the builder is running.

In the previous example, the generated ISO image will be available on the host system at `/tmp/nixos.iso`. It can be
used to install NixOS on an x86-64 system and will fetch the bootstrapping information from
`http://10.0.0.2:8080/bootstrap.json` during installation.

## Installation

Host the bootstrapping information JSON file on an HTTP server so it can be accessed during installation. Ensure that
the HTTP server:

* Can be reached during installation at the same URL specified when building the ISO image.
* Is not publicly-accessible as it may contain an unencrypted age private key.

Mount the ISO image as appropriate and boot the system. The system will reboot when finished.
