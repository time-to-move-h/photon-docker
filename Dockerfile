# ─────────────────────────────────────────────────────────────────────────────
# Photon Geocoder – Dockerfile
# Supports:
#   • photon_data/ folder already present  → start immediately
#   • *.jsonl.zst dump present             → import then start
#   • neither present                      → auto-download from GraphHopper
# ─────────────────────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

LABEL maintainer="you" \
      description="Komoot Photon geocoder with auto-download & import support"

ARG PHOTON_VERSION=1.0.0

# Install runtime dependencies
RUN apk add --no-cache \
      bash \
      curl \
      wget \
      zstd \
      bzip2 \
      tar \


      ca-certificates

WORKDIR /photon

# Download the photon JAR from GitHub releases
RUN curl -fsSL \
    "https://github.com/komoot/photon/releases/download/${PHOTON_VERSION}/photon-${PHOTON_VERSION}.jar" \
    -o photon.jar

# Data directory (mounted as a volume)
RUN mkdir -p /photon/photon_data /photon/dumps

COPY entrypoint.sh /photon/entrypoint.sh
RUN chmod +x /photon/entrypoint.sh

VOLUME ["/photon/photon_data", "/photon/dumps"]

EXPOSE 2322

HEALTHCHECK \
  --interval=30s \
  --timeout=10s \
  --start-period=300s \
  --retries=5 \
  CMD curl -fsSL "http://localhost:2322/status" > /dev/null || exit 1

ENTRYPOINT ["/photon/entrypoint.sh"]
