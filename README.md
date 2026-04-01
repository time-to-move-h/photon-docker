<div align="center">

<img src="https://raw.githubusercontent.com/komoot/photon/master/photon.png" alt="Photon Logo" width="80" />

# 🌍 Photon Geocoder — Docker

**Self-hosted geocoding, zero friction.**
Auto-downloads country, continent, or planet data and starts serving in minutes.

[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Photon](https://img.shields.io/badge/Photon-0.7.4-4CAF50?style=flat-square)](https://github.com/komoot/photon)
[![OpenStreetMap](https://img.shields.io/badge/Data-OpenStreetMap-7EBC6F?style=flat-square&logo=openstreetmap&logoColor=white)](https://www.openstreetmap.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

[Quick Start](#-quick-start) · [Configuration](#-configuration) · [Regions](#-region-reference) · [API Usage](#-api-usage) · [Data Options](#-data-source-options)

</div>

---

## ✨ Features

- 🚀 **One-command setup** — just set a region and go
- 🌐 **Any scale** — from Luxembourg to the entire planet
- 📦 **Flexible data ingestion** — auto-download, pre-compiled folder, or `.jsonl.zst` dump
- 🗣️ **Multi-language support** — configure languages for dump imports
- ⚙️ **Single `.env` config** — all tunables in one place
- 🔁 **Forward & reverse geocoding** — full Photon API support

---

## 🚀 Quick Start

```bash
# 1. Clone and configure
cp .env.example .env
nano .env  # Set REGION=de (or any country/continent)

# 2. Launch
docker compose up -d

# 3. Follow progress
docker compose logs -f
```

> The API will be live at **http://localhost:2322** once data is downloaded and indexed.

---

## ⚙️ Configuration

All settings live in your `.env` file:

| Variable | Default | Description |
|---|---|---|
| `PHOTON_VERSION` | `1.0.1` | Photon release to build |
| `REGION` | `de` | Country code, continent name, or `planet` |
| `DATA_TYPE` | `db` | `db` = precompiled archive · `dump` = jsonl.zst import |
| `AUTO_DOWNLOAD` | `true` | Auto-fetch data if none is found |
| `LANGUAGES` | `en,de,fr,es` | Comma-separated languages *(dump import only)* |
| `JAVA_OPTS` | `-Xmx2g -Xms512m` | JVM heap settings — tune for region size |
| `PHOTON_OPTS` | *(empty)* | Extra Photon flags (e.g. `-cors-any`) |
| `HOST_PORT` | `2322` | Port exposed on the host |
| `BASE_URL` | GraphHopper CDN | Override the data download base URL |
| `SKIP_MD5` | `false` | Skip MD5 checksum verification |
| `MEMORY_LIMIT` | `4g` | Docker memory cap |

---

## 🌍 Region Reference

Set `REGION` to any of the following:

### 🌐 Continents & Planet

| Value | Coverage | Notes |
|---|---|---|
| `planet` | 🌍 Entire world | ~90 GB extracted |
| `europe` | 🇪🇺 European continent | |
| `asia` | 🌏 Asian continent | |
| `africa` | 🌍 African continent | |
| `north-america` | 🌎 North America | |
| `south-america` | 🌎 South America | |
| `oceania` | 🌏 Oceania | |

### 🗺️ Countries

Use [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2) codes or full country names:

```
de  fr  es  it  pt  gb  nl  be  at  ch
pl  cz  hu  ro  se  no  dk  fi  gr  hr
us  ca  mx  br  ar  au  jp  cn  in  ...
```

> **Examples:** `REGION=fr` · `REGION=spain` · `REGION=north-america`

---

## 💾 Memory Guidelines

Scale your JVM and container memory to match your region:

| Region size | Example | `JAVA_OPTS (-Xmx)` | `MEMORY_LIMIT` |
|---|---|---|---|
| 🟢 Small country | `is`, `lu`, `mt` | `512m` | `1g` |
| 🟡 Medium country | `de`, `fr`, `es` | `2g` | `4g` |
| 🟠 Large / continent | `us`, `europe` | `4g` | `8g` |
| 🔴 Planet | `planet` | `8g`+ | `12g`+ |

---

## 📂 Data Source Options

### Option 1 — Auto-download *(default, recommended)*

Leave volumes empty. The entrypoint handles everything.

```bash
# Pre-compiled DB (fastest startup)
REGION=fr docker compose up -d

# jsonl.zst dump (richer data: more languages + full geometries)
REGION=fr DATA_TYPE=dump docker compose up -d
```

### Option 2 — Drop in a `photon_data/` folder

Already have a working Photon data directory?

1. Uncomment the `photon_data` bind-mount in `docker-compose.yml`
2. Place your directory at `./photon_data/`
3. Run `docker compose up -d` — the entrypoint detects it and skips all downloads

### Option 3 — Drop in a `.jsonl.zst` dump

1. Uncomment the `photon_dumps` bind-mount in `docker-compose.yml`
2. Place your file at `./dumps/photon-dump-*.jsonl.zst`
3. Optionally set `AUTO_DOWNLOAD=false`
4. Run `docker compose up -d`

---

## 🔌 API Usage

```bash
# Forward geocoding
curl "http://localhost:2322/api?q=berlin&limit=5"

# Reverse geocoding
curl "http://localhost:2322/api/reverse?lat=52.5200&lon=13.4050"

# Health / status check
curl "http://localhost:2322/status"
```

<details>
<summary>📄 Example response (forward geocoding)</summary>

```json
{
  "features": [
    {
      "geometry": { "coordinates": [13.3888599, 52.5170365], "type": "Point" },
      "type": "Feature",
      "properties": {
        "osm_id": 240109189,
        "country": "Germany",
        "city": "Berlin",
        "name": "Berlin",
        "state": "Berlin",
        "type": "city"
      }
    }
  ],
  "type": "FeatureCollection"
}
```

</details>

---

## 🛠️ Useful Commands

```bash
# Build image without starting
docker compose build

# Start in background
docker compose up -d

# Stream logs
docker compose logs -f

# Stop services
docker compose down

# Rebuild after Dockerfile / entrypoint changes
docker compose up -d --build

# ⚠️ Full reset — deletes all downloaded data
docker compose down -v
```

---

## 🔄 Updating Data

```bash
# Simple (causes brief downtime)
docker compose down -v
REGION=de docker compose up -d

# Zero-downtime reimport
# Use Photon's -cluster flag — see the Photon docs for details
```

---

## 🔗 Resources

| Resource | Link |
|---|---|
| Photon GitHub | [komoot/photon](https://github.com/komoot/photon) |
| GraphHopper Planet data | [download1.graphhopper.com/public/](https://download1.graphhopper.com/public/) |
| GraphHopper Europe data | [.../public/europe/](https://download1.graphhopper.com/public/europe/) |
| Photon dump exports blog post | [nominatim.org — Photon exports renewed](https://nominatim.org/2025/08/13/photon-exports-renewed.html) |
| OpenStreetMap | [openstreetmap.org](https://www.openstreetmap.org/) |

---

<div align="center">

Built on [Komoot Photon](https://github.com/komoot/photon) · Data © [OpenStreetMap contributors](https://www.openstreetmap.org/copyright)

</div>











---
# Hi, I'm H 👋

Principal Engineer & Founder of **HD International Ltd** — a Bulgarian-based software consultancy delivering
enterprise-grade solutions across Architecture, Cloud, AI, DevOps, and Operations.

---

## 🏢 HD International Ltd

> *Engineering clarity from complexity.*

We partner with startups and enterprises to design, build, and operate resilient, scalable systems.

---

## 🛠️ Services

**Software Architecture**
Designing scalable, maintainable systems — microservices, event-driven architecture, domain-driven
design, and API strategy.

**Cloud Engineering** · AWS · GCP · Azure . On Premise
Infrastructure design, cloud migrations, cost optimisation, and multi-cloud strategies.

**DevOps & CI/CD**
End-to-end pipeline automation, containerisation (Docker/Kubernetes), GitOps, and platform engineering.

**AI & ML Solutions**
Integrating LLMs, building ML pipelines, and delivering production-ready AI features into existing products.

**Operations & SRE**
Observability, incident management, SLA design, and reliability engineering for critical systems.

---

## 🧰 Core Stack

**Languages**
`Java` `C#` `PHP 8+` `Python` `Go` `TypeScript` `JavaScript` `Rust` `Bash` `Ruby` `Scala` `Kotlin`

**Frameworks & Libraries**
`Spring Boot` `ASP.NET Core` `Laravel` `Symfony` `FastAPI` `Django` `Flask` `NestJS` `Express`
`React` `Next.js` `Angular` `LangChain` `LlamaIndex` `Celery` `GraphQL`

**Cloud & Infrastructure**
`AWS` `GCP` `Azure` `Terraform` `Pulumi` `CDK` `Ansible` `Packer` `Vault` `Consul`

**Containers & Orchestration**
`Docker` `Kubernetes` `Helm` `Istio` `ArgoCD` `FluxCD` `Kustomize` `Rancher` `OpenShift`

**CI/CD & DevOps**
`GitHub Actions` `GitLab CI` `Jenkins` `CircleCI` `TeamCity` `Tekton` `SonarQube` `Nexus`

**Data & Messaging**
`PostgreSQL` `MySQL` `MongoDB` `Redis` `Elasticsearch` `Kafka` `RabbitMQ` `NATS` `Kinesis`
`Snowflake` `BigQuery` `dbt` `Airflow` `Spark`

**AI & ML**
`LangChain` `LlamaIndex` `OpenAI API` `Anthropic API` `HuggingFace` `PyTorch` `TensorFlow`
`scikit-learn` `MLflow` `Weights & Biases` `Pinecone` `Weaviate` `FAISS`

**Observability & Operations**
`Datadog` `Prometheus` `Grafana` `Loki` `Jaeger` `OpenTelemetry` `PagerDuty` `Sentry`
`ELK Stack` `New Relic` `Dynatrace`

**Security & Compliance**
`Vault` `Trivy` `Snyk` `OWASP ZAP` `Falco` `Checkov` `AWS Security Hub` `IAM` `OAuth2` `OIDC`

---

## 📬 Work With Us

We take on select consulting engagements and fractional CTO mandates.

📧 hdinternational82@gmail.com 
💼 [LinkedIn]([https://www.linkedin.com/in/time-to-move-h/])

> *Registered in Bulgaria & Plovdiv · HD International Ltd*
> VAT BG-204723748
