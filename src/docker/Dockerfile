FROM docker.io/nixos/nix

ARG NIXOS_VERSION=25.11

RUN echo "sandbox = false" >> /etc/nix/nix.conf \
  && echo "filter-syscalls = false" >> /etc/nix/nix.conf
RUN nix-channel --remove nixpkgs || true && \
  nix-channel --add https://nixos.org/channels/nixos-${NIXOS_VERSION} nixpkgs && \
  nix-channel --update && \
  nix-env -iA nixpkgs.util-linux

COPY container /opt/container/

RUN chmod +x /opt/container/bin/build-iso.sh

VOLUME /output

WORKDIR /opt/container/bin

ENTRYPOINT ["/opt/container/bin/build-iso.sh"]
