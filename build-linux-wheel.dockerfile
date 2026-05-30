# One-shot Docker builder for the patched NT wheel targeting linux/amd64.
# Mirrors NT's upstream build env: Python 3.13 + Rust stable + poetry-core +
# numpy + Cython. Output is written to /out/dist (mount to host wheels/).
#
# Usage (from /Users/sonnymai/src/nautilus_trader-hyperpoo-patch):
#   docker buildx build --platform linux/amd64 -f build-linux-wheel.dockerfile \
#       --output type=local,dest=./wheels-linux .

FROM --platform=linux/amd64 python:3.13-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Build deps: rustc/cargo (via rustup), C toolchain for crates with C build.rs
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        curl \
        git \
        libssl-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
        sh -s -- -y --default-toolchain stable --profile minimal

# uv's build isolation runs build.py in a fresh subprocess that doesn't
# always inherit our PATH manipulation, so the build script's `rustc
# --version` check fails. Symlink rustc/cargo into the system bin so
# they're discoverable regardless of PATH inheritance.
RUN ln -sf /usr/local/cargo/bin/rustc /usr/bin/rustc \
    && ln -sf /usr/local/cargo/bin/cargo /usr/bin/cargo \
    && rustc --version && cargo --version

RUN pip install --no-cache-dir uv==0.11.12

WORKDIR /src
COPY . /src

RUN uv build --wheel --out-dir /out

# Final stage: just emit the wheels so `--output type=local` picks them up
FROM scratch AS export
COPY --from=builder /out /
