# syntax=docker/dockerfile:latest

FROM alpine:latest AS build

# Getting things to work as an underprivileged user was too hard. I give up. Root for now.
ENV USER=root
USER ${USER}:${USER}

# add vips-dev and deps
RUN set -x -o pipefail \
 && apk add --no-cache alpine-sdk \
 && apk add --no-cache \
    git curl build-base clang zlib libxml2 glib gobject-introspection \
    libjpeg-turbo libexif lcms2 fftw giflib libpng \
    libwebp orc tiff poppler-glib librsvg libgsf openexr \
    libheif libimagequant pango-dev \
 && apk add --no-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community --repository http://dl-3.alpinelinux.org/alpine/edge/main vips-dev

# Install Elixir, Erlang (latter automatically as dep)
RUN apk add --no-cache elixir

# Add Rust and configure
# So apparently dynamically-linked crates won't compile correctly on musl toolchains (as in alpine)
# so we will force static compilation.
ENV RUSTFLAGS="-C target-feature=-crt-static"
# this is based on Erlang version; setting it manually here worked around a bug:
ENV RUSTLER_NIF_VERSION=2.15
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain nightly
# Rustup should hopefully modify PATH appropriately, otherwise: EDIT Aaaaand nope, it didn't, so
ENV PATH=/root/.cargo/bin:/home/$USER/.cargo/bin:$PATH

WORKDIR /usr/src/app

COPY mix.exs mix.lock /usr/src/app/

# for debugging Rust compilation issues
ENV RUST_BACKTRACE=1

RUN mix local.hex --force && \
  mix deps.get --force && \
  mix local.rebar --force && \
  mix deps.compile

COPY . .

RUN mix test
