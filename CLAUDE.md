# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repo provides a local observability stack for monitoring Claude Code telemetry via OpenTelemetry. It captures logs, metrics, and traces from Claude Code and visualizes them in Grafana.

## Stack

- **OTel Collector** — receives OTLP telemetry from Claude Code (gRPC :4317, HTTP :4318), exports to Loki, Prometheus, and Tempo; exposes internal metrics at :8888
- **Loki** — log storage (:3100), receives logs from OTel Collector via OTLP HTTP
- **Prometheus** — metrics storage (:9090), receives metrics via remote write from OTel Collector and also scrapes the collector's internal metrics at :8888
- **Tempo** — trace storage (:3200 HTTP, :4319 gRPC), receives traces from OTel Collector
- **Grafana** — visualization (:3000, admin/admin), auto-provisioned with all three datasources and a Claude Code dashboard

## Running the stack

```bash
docker compose up -d
docker compose down
docker compose logs -f <service>   # otel-collector | loki | prometheus | tempo | grafana
```

## Sending Claude Code telemetry to this stack

Source `claude-env.sh` before starting Claude Code:

```bash
source ./claude-env.sh
claude
```

This sets `OTEL_*` and `CLAUDE_CODE_*` environment variables pointing to `localhost:4317` (gRPC) and `localhost:4318` (HTTP for beta tracing). Uncomment the optional lines at the bottom of `claude-env.sh` to also capture tool content, tool details, or user prompts.

## Telemetry pipeline

```
Claude Code → OTel Collector → Loki    (logs)
                             → Prometheus (metrics, via remote write)
                             → Tempo    (traces)
```

## Provisioning

Grafana datasources (`grafana/provisioning/datasources/datasources.yaml`) and dashboards (`grafana/provisioning/dashboards/`) are auto-provisioned on container start. The main dashboard JSON is at `grafana/provisioning/dashboards/claude-code.json`. Changes take effect on `docker compose restart grafana`.
