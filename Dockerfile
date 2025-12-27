# frozen_string_literal: true

# Multi-stage Dockerfile for llm-docs-builder
# Creates a minimal Docker image (~50MB) for running the CLI without Ruby installation

# Stage 1: Builder
FROM ruby:4.0-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git

# Set working directory
WORKDIR /gem

# Copy gemspec and version files first for better caching
COPY llm-docs-builder.gemspec ./
COPY lib/llm_docs_builder/version.rb ./lib/llm_docs_builder/

# Copy the rest of the gem (needed for gemspec)
COPY . .

# Initialize git repo so gemspec can use git ls-files
RUN git init && \
    git add -A && \
    git config user.email "docker@localhost" && \
    git config user.name "Docker Build" && \
    git commit -m "Docker build"

# Install dependencies
RUN bundle config set --local without 'development test' && \
    bundle install

# Build the gem
RUN gem build llm-docs-builder.gemspec

# Stage 2: Runtime
FROM ruby:4.0-alpine

# Install runtime dependencies and build tools for native extensions
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    libxml2 \
    libxslt

# Copy built gem and install it (needs build tools for nokogiri)
COPY --from=builder /gem/llm-docs-builder-*.gem /tmp/
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    libxml2-dev \
    libxslt-dev && \
    gem install /tmp/llm-docs-builder-*.gem --no-document && \
    rm /tmp/llm-docs-builder-*.gem && \
    apk del .build-deps

# Set working directory for user files
WORKDIR /workspace

# Set entrypoint to the CLI
ENTRYPOINT ["llm-docs-builder"]

# Default command shows help
CMD ["--help"]

# Metadata
LABEL maintainer="Maciej Mensfeld <maciej@mensfeld.pl>"
LABEL description="Build and optimize documentation for LLMs - generate llms.txt, transform markdown, and more"
LABEL org.opencontainers.image.source="https://github.com/mensfeld/llm-docs-builder"
LABEL org.opencontainers.image.licenses="MIT"
