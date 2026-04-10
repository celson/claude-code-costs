# Stack Improvements Design

**Date:** 2026-04-09
**Status:** Approved

## Summary

Comprehensive improvement of the claude-code-costs observability stack covering:
1. Docker image updates to latest stable versions
2. Portability fix for `claude-env.sh`
3. Data retention configuration for Loki and Prometheus
4. Dashboard datasource fixes and traces↔logs↔metrics correlation

## 1. Image Updates

All images in `docker-compose.yml` will be updated to their latest stable versions at implementation time, pinned to explicit tags (no `latest` generic tag).

| Service | Current | Action |
|---|---|---|
| OTel Collector | `0.107.0` | Update to latest stable |
| Loki | `3.1.0` | Update to latest stable |
| Prometheus | `v2.53.0` | Update to latest stable (v3.x) |
| Tempo | `2.6.1` | Update to latest stable (revert if breaking) |
| Grafana | `11.1.0` | Update to latest stable (11.x) |

**Constraint:** If Tempo's latest version introduces breaking config changes, pin it to the highest compatible version and document the reason.

## 2. `claude-env.sh` Portability

Replace the two hardcoded IP addresses (`100.74.255.104`) with a configurable `OTEL_HOST` variable that defaults to `localhost`.

**Before:**
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://100.74.255.104:4317"
export BETA_TRACING_ENDPOINT="http://100.74.255.104:4318"
```

**After:**
```bash
OTEL_HOST="${OTEL_HOST:-localhost}"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://${OTEL_HOST}:4317"
export BETA_TRACING_ENDPOINT="http://${OTEL_HOST}:4318"
```

Users pointing to a remote host (e.g., via Tailscale) set `OTEL_HOST` before sourcing:
```bash
OTEL_HOST=100.74.255.104 source ./claude-env.sh
```

## 3. Data Retention

### Loki
Create a local `loki-config.yaml` with retention enabled (30 days). Mount it in `docker-compose.yml` and update the Loki command to use it.

Key config additions:
```yaml
compactor:
  retention_enabled: true
  retention_delete_delay: 2h
  working_directory: /loki/retention
limits_config:
  retention_period: 30d
```

### Prometheus
Add storage retention flag to the Prometheus command in `docker-compose.yml`:
```yaml
command:
  - '--storage.tsdb.retention.time=30d'
```

### Tempo
Keep the existing 72h block retention — traces are larger and have lower long-term value for this use case.

## 4. Dashboard and Datasource Fixes

### Dashboard (`grafana/provisioning/dashboards/claude-code.json`)

**Problem:** The dashboard was exported from Grafana Cloud and contains:
- `__inputs` block referencing `grafanacloud-braw-logs` (a remote Grafana Cloud datasource)
- `__requires` block with `pluginVersion: 13.0.0`, incompatible with Grafana 11
- Panel-level datasource references pointing to the Cloud UID

**Fix:** Remove the `__inputs` and `__requires` blocks. Update all datasource references in panels to use the local UID `loki` (already defined in `datasources.yaml`). The dashboard will then work out-of-the-box without manual import configuration.

### Datasource Correlation (`grafana/provisioning/datasources/datasources.yaml`)

**Tempo datasource** — add `tracesToMetrics` so trace spans link to Prometheus metrics:
```yaml
tracesToMetrics:
  datasourceUid: prometheus
```

**Loki datasource** — add `derivedFields` so log lines containing a `trace_id` become clickable links into Tempo:
```yaml
jsonData:
  derivedFields:
    - name: TraceID
      matcherRegex: "trace_id=(\\w+)"
      url: "$${__value.raw}"
      datasourceUid: tempo
```

**Result:** Full bidirectional navigation — traces link to logs, logs link to traces, traces link to metrics.

## Files Changed

| File | Change |
|---|---|
| `docker-compose.yml` | Update all image versions; add Prometheus retention flag |
| `claude-env.sh` | Replace hardcoded IPs with `OTEL_HOST` variable |
| `loki-config.yaml` | New file — Loki config with 30-day retention |
| `grafana/provisioning/datasources/datasources.yaml` | Add `tracesToMetrics` and `derivedFields` |
| `grafana/provisioning/dashboards/claude-code.json` | Remove `__inputs`/`__requires`, fix datasource UIDs |

## Out of Scope

- Alerting (not requested)
- Security hardening beyond portability (not requested)
- New dashboard panels (not requested)
