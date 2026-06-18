# pgdocker — a containerized environment for paritytech/playground-cli.
#
# Bakes Node (for frontend builds), the Kubo (IPFS) CLI that `pg deploy`
# requires, and the playground-cli binary/toolchain into the image so nothing
# has to be installed on the host.
FROM node:22-bookworm

# --- Kubo (IPFS) CLI -------------------------------------------------------
# `pg deploy` shells out to `ipfs` (Kubo) to pin content to Polkadot Bulletin.
ARG KUBO_VERSION=0.42.0
# TARGETARCH is provided by BuildKit (amd64 / arm64) and matches Kubo's asset
# naming (linux-amd64 / linux-arm64). Falls back to amd64 for plain builds.
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Base toolchain: curl/git/ca-certificates plus build-essential for any app
# that compiles native deps during a frontend build.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        git \
        ca-certificates \
        build-essential \
    && rm -rf /var/lib/apt/lists/*

# Download the official Kubo release for the target arch and put `ipfs` on PATH.
RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    url="https://dist.ipfs.tech/kubo/v${KUBO_VERSION}/kubo_v${KUBO_VERSION}_linux-${arch}.tar.gz"; \
    curl -fsSL "$url" -o /tmp/kubo.tar.gz; \
    tar -xzf /tmp/kubo.tar.gz -C /tmp; \
    install -m 0755 /tmp/kubo/ipfs /usr/local/bin/ipfs; \
    rm -rf /tmp/kubo /tmp/kubo.tar.gz; \
    ipfs --version

# --- playground-cli --------------------------------------------------------
# install.sh drops the binary into ~/.polkadot/bin and symlinks `playground`
# + `pg` into ~/.local/bin. Put both dirs on PATH for every shell, the
# entrypoint, and the RUN steps below. HOME is /root (image runs as root).
ENV PATH="/root/.polkadot/bin:/root/.local/bin:${PATH}"

# Run the official installer so the binary + toolchain are baked in. The
# installer ends by running `pg login --yes` to pre-install deps; that step
# needs outbound network and can be flaky at build time, so we tolerate its
# failure here (deps are also set up on the first real `pg login`) and instead
# assert the binary itself landed in the next step.
RUN curl -fsSL https://raw.githubusercontent.com/paritytech/playground-cli/main/install.sh -o /tmp/install.sh \
    && (bash /tmp/install.sh || echo "install.sh post-install (pg login --yes) did not complete; binary verified separately") \
    && rm -f /tmp/install.sh

# Fail the build if the playground binary is not actually on PATH.
RUN command -v pg && command -v playground && pg --version

# --- runtime ---------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Apps to deploy live here; docker-compose bind-mounts ./apps onto it.
WORKDIR /work/apps

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Default to an interactive shell; overridden by `pg ...` invocations.
CMD ["bash"]
