# syntax=docker/dockerfile:1

# Gateway: a persistent workbench for long-running agents that drive other
# agents across hosts. Everything here is pinned and checksum-verified so the
# image can be rebuilt identically months from now.

ARG PYTHON_VERSION=3.13
FROM python:${PYTHON_VERSION}-slim-bookworm

ARG TARGETARCH

# --- OS packages -----------------------------------------------------------
# Kept in one layer, with the apt lists dropped, so the cache stays small.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      fd-find \
      git \
      gnupg \
      jq \
      less \
      locales \
      openssh-client \
      procps \
      ripgrep \
      rsync \
      tini \
      tmux \
      unzip \
    && rm -rf /var/lib/apt/lists/*

# Debian names the fd binary `fdfind` to avoid a clash; agents expect `fd`.
RUN ln -s "$(command -v fdfind)" /usr/local/bin/fd

RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- neovim ----------------------------------------------------------------
# Upstream release tarball: Debian's nvim is years behind and breaks modern
# plugins. Checksums come from the published .sha256sum files.
ARG NVIM_VERSION=v0.12.5
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) nvim_arch=x86_64 ;; \
      arm64) nvim_arch=arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    base="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}"; \
    tarball="nvim-linux-${nvim_arch}.tar.gz"; \
    curl -fsSL --retry 3 -o /tmp/nvim.tar.gz "${base}/${tarball}"; \
    curl -fsSL --retry 3 -o /tmp/nvim.sha256 "${base}/${tarball}.sha256sum"; \
    echo "$(awk '{print $1}' /tmp/nvim.sha256)  /tmp/nvim.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/nvim.tar.gz -C /opt; \
    mv "/opt/nvim-linux-${nvim_arch}" /opt/nvim; \
    ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim; \
    rm -f /tmp/nvim.tar.gz /tmp/nvim.sha256; \
    nvim --version | head -1

# --- herdr -----------------------------------------------------------------
# herdr.dev ships a `curl | sh` installer, but it always takes "latest" and so
# can't be reproduced. We fetch the same release asset at a pinned version and
# verify the SHA-256 the installer would have checked. `herdr update` still
# works at runtime for ad-hoc upgrades.
ARG HERDR_VERSION=0.9.3
ARG HERDR_SHA256_AMD64=18a8dc65f1c2fa485884344356dea1cfd911c6f06cf46fa78e193f4087f4dba7
ARG HERDR_SHA256_ARM64=4de7aa3e25678812e92960de64f7c2aaa1bca1f0f80a3c5e559837e231e1f5c0
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) herdr_arch=x86_64; herdr_sha="${HERDR_SHA256_AMD64}" ;; \
      arm64) herdr_arch=aarch64; herdr_sha="${HERDR_SHA256_ARM64}" ;; \
      *) echo "unsupported arch: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL --retry 3 \
      -o /usr/local/bin/herdr \
      "https://github.com/herdrdev/herdr/releases/download/v${HERDR_VERSION}/herdr-linux-${herdr_arch}"; \
    echo "${herdr_sha}  /usr/local/bin/herdr" | sha256sum -c -; \
    chmod +x /usr/local/bin/herdr

# --- python tooling --------------------------------------------------------
# uv handles per-project venvs; nothing agent-side should touch system python.
ARG UV_VERSION=0.9.2
RUN set -eux; \
    curl -fsSL --retry 3 "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh; \
    uv --version

# --- application user ------------------------------------------------------
# uid/gid 1000 so bind-mounted state on the VM lines up with the IT-created
# application account that owns /srv/gateway.
ARG APP_UID=1000
ARG APP_GID=1000
RUN groupadd -g "${APP_GID}" agent \
    && useradd -m -u "${APP_UID}" -g "${APP_GID}" -s /bin/bash agent \
    && mkdir -p /workspace && chown agent:agent /workspace

COPY --chown=root:root bin/entrypoint.sh bin/doctor.sh /usr/local/bin/
COPY --chown=agent:agent config/tmux.conf config/gateway.tmux.conf /etc/gateway/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/doctor.sh

USER agent
WORKDIR /workspace

ENV HOME=/home/agent \
    PATH=/home/agent/.local/bin:$PATH \
    SHELL=/bin/bash \
    TMUX_CONF=/etc/gateway/gateway.tmux.conf \
    GATEWAY_SESSION=gateway

# tini reaps the agent processes that tmux orphans over a long-lived session.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["supervise"]
