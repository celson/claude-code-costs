# Stack Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update Docker image versions, fix `claude-env.sh` portability, configure data retention for Loki/Prometheus, and fix Grafana dashboard datasource references and correlation.

**Architecture:** All changes are configuration-only — no application code. Each task is independently verifiable via Docker health checks and Grafana UI. Tasks 1–2 can be done in any order; Tasks 3–4 both modify `docker-compose.yml` so do them sequentially; Task 5 modifies datasources; Task 6 fixes the dashboard JSON.

**Tech Stack:** Docker Compose, OpenTelemetry Collector, Loki, Prometheus, Tempo, Grafana

---

## File Map

| File | Action | Responsible for |
|---|---|---|
| `docker-compose.yml` | Modify | Image versions + Loki config mount + Prometheus retention flag |
| `claude-env.sh` | Modify | Replace hardcoded IPs with `OTEL_HOST` variable |
| `loki-config.yaml` | Create | Loki local config with 30-day retention |
| `grafana/provisioning/datasources/datasources.yaml` | Modify | Add `tracesToMetrics` (Tempo) and `derivedFields` (Loki) |
| `grafana/provisioning/dashboards/claude-code.json` | Modify | Remove `__inputs`/`__requires` blocks |

---

## Task 1: Update Docker image versions

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Look up latest stable image versions**

Check Docker Hub for the latest stable tags:
- https://hub.docker.com/r/otel/opentelemetry-collector-contrib/tags
- https://hub.docker.com/r/grafana/loki/tags
- https://hub.docker.com/r/prom/prometheus/tags
- https://hub.docker.com/r/grafana/tempo/tags
- https://hub.docker.com/r/grafana/grafana/tags

Pick the highest non-`latest`, non-pre-release tag for each. For Prometheus, prefer v3.x if stable.

- [ ] **Step 2: Update image versions in `docker-compose.yml`**

Replace the `image:` lines for all five services with the versions found in Step 1. Example structure (fill in actual versions):

```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:X.Y.Z   # was 0.107.0
  loki:
    image: grafana/loki:X.Y.Z                           # was 3.1.0
  prometheus:
    image: prom/prometheus:vX.Y.Z                       # was v2.53.0
  tempo:
    image: grafana/tempo:X.Y.Z                          # was 2.6.1
  grafana:
    image: grafana/grafana:X.Y.Z                        # was 11.1.0
```

- [ ] **Step 3: Pull new images**

```bash
docker compose pull
```

Expected: All five images download successfully with no errors.

- [ ] **Step 4: Start the stack and verify all services are healthy**

```bash
docker compose up -d
docker compose ps
```

Expected: All services show `healthy` status. If Tempo shows `unhealthy` or fails to start, check its logs:

```bash
docker compose logs tempo
```

If Tempo's config format changed in the new version, pin Tempo back to `2.6.1` in `docker-compose.yml` and re-pull/up. Document the pinned version with a comment:

```yaml
tempo:
  image: grafana/tempo:2.6.1  # pinned: newer version has breaking config changes
```

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "chore: update Docker image versions to latest stable"
```

---

## Task 2: Fix `claude-env.sh` portability

**Files:**
- Modify: `claude-env.sh`

- [ ] **Step 1: Replace hardcoded IPs with `OTEL_HOST` variable**

Open `claude-env.sh`. Replace the two hardcoded IP lines:

```bash
# Before:
export OTEL_EXPORTER_OTLP_ENDPOINT="http://100.74.255.104:4317"
# ...
export BETA_TRACING_ENDPOINT="http://100.74.255.104:4318"
```

With:

```bash
# After — top of file, before the exports:
OTEL_HOST="${OTEL_HOST:-localhost}"

export OTEL_EXPORTER_OTLP_ENDPOINT="http://${OTEL_HOST}:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"
# ...
export BETA_TRACING_ENDPOINT="http://${OTEL_HOST}:4318"
```

- [ ] **Step 2: Verify default behavior**

```bash
source ./claude-env.sh
echo $OTEL_EXPORTER_OTLP_ENDPOINT
```

Expected output: `http://localhost:4317`

- [ ] **Step 3: Verify override behavior**

```bash
OTEL_HOST=192.168.1.10 source ./claude-env.sh
echo $OTEL_EXPORTER_OTLP_ENDPOINT
```

Expected output: `http://192.168.1.10:4317`

- [ ] **Step 4: Commit**

```bash
git add claude-env.sh
git commit -m "fix: replace hardcoded OTel host IPs with configurable OTEL_HOST variable"
```

---

## Task 3: Configure Loki data retention (30 days)

**Files:**
- Create: `loki-config.yaml`
- Modify: `docker-compose.yml`

- [ ] **Step 1: Create `loki-config.yaml`**

Create the file at the repo root with this content:

```yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: warn

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 30d

compactor:
  working_directory: /loki/retention
  retention_enabled: true
  retention_delete_delay: 2h
  delete_request_store: filesystem

analytics:
  reporting_enabled: false
```

- [ ] **Step 2: Mount the config in `docker-compose.yml`**

In the `loki` service, replace the existing `command` and add a `volumes` mount:

```yaml
loki:
  image: grafana/loki:X.Y.Z
  container_name: loki
  ports:
    - "3100:3100"
  command: -config.file=/etc/loki/config.yaml
  volumes:
    - ./loki-config.yaml:/etc/loki/config.yaml
    - loki-data:/loki
  restart: unless-stopped
  healthcheck:
    test: ["CMD-SHELL", "wget -q --tries=1 -O- http://localhost:3100/ready || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 5
```

- [ ] **Step 3: Restart Loki and verify it starts with the new config**

```bash
docker compose up -d --force-recreate loki
docker compose logs loki | head -30
```

Expected: Loki starts, no config errors. The log should mention `compactor` initializing.

```bash
docker compose ps loki
```

Expected: `healthy`

- [ ] **Step 4: Commit**

```bash
git add loki-config.yaml docker-compose.yml
git commit -m "feat: configure Loki with 30-day log retention"
```

---

## Task 4: Configure Prometheus data retention (30 days)

**Files:**
- Modify: `docker-compose.yml`

- [ ] **Step 1: Add retention flag to Prometheus command**

In the `prometheus` service `command` block, add the retention flag:

```yaml
prometheus:
  image: prom/prometheus:vX.Y.Z
  container_name: prometheus
  command:
    - '--config.file=/etc/prometheus/prometheus.yml'
    - '--web.enable-remote-write-receiver'
    - '--storage.tsdb.retention.time=30d'
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus-data:/prometheus
  ports:
    - "9090:9090"
  restart: unless-stopped
  healthcheck:
    test: ["CMD-SHELL", "wget -q --tries=1 -O- http://localhost:9090/-/healthy || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 5
```

- [ ] **Step 2: Restart Prometheus and verify the flag is active**

```bash
docker compose up -d --force-recreate prometheus
```

Verify the flag was picked up:

```bash
curl -s http://localhost:9090/api/v1/status/flags | grep retention
```

Expected: output contains `"storage.tsdb.retention.time":"30d"`

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: configure Prometheus with 30-day metrics retention"
```

---

## Task 5: Add traces↔logs↔metrics correlation in Grafana

**Files:**
- Modify: `grafana/provisioning/datasources/datasources.yaml`

- [ ] **Step 1: Add `tracesToMetrics` to Tempo datasource and `derivedFields` to Loki datasource**

Replace the full contents of `grafana/provisioning/datasources/datasources.yaml` with:

```yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    uid: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    jsonData:
      maxLines: 1000
      derivedFields:
        - name: TraceID
          matcherRegex: '"trace_id"\s*:\s*"(\w+)"'
          url: "$${__value.raw}"
          datasourceUid: tempo
          urlDisplayLabel: "Open in Tempo"

  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    jsonData:
      timeInterval: "15s"

  - name: Tempo
    type: tempo
    uid: tempo
    access: proxy
    url: http://tempo:3200
    jsonData:
      tracesToLogs:
        datasourceUid: loki
        mapTagNamesEnabled: true
      tracesToMetrics:
        datasourceUid: prometheus
```

Note: The `derivedFields` regex `"trace_id"\s*:\s*"(\w+)"` matches OTel JSON-structured log lines. If Claude Code logs emit `trace_id` in a different format (e.g., as a Loki label rather than inline JSON), the regex may need adjustment — check a sample log line in Grafana's Explore view for Loki to confirm the format.

- [ ] **Step 2: Restart Grafana to apply new datasource config**

```bash
docker compose restart grafana
```

- [ ] **Step 3: Verify datasources load correctly**

Open http://localhost:3000 (admin/admin). Go to **Connections → Data sources**.

Verify:
- Loki: click "Explore" → write `{service_name="claude-code"}` → should return logs
- Tempo: click "Explore" → search for a trace → clicking it should show a "Logs" tab linking to Loki
- Prometheus: click "Explore" → query `up` → should return metrics

- [ ] **Step 4: Commit**

```bash
git add grafana/provisioning/datasources/datasources.yaml
git commit -m "feat: add traces-to-metrics and logs-to-traces correlation in Grafana datasources"
```

---

## Task 6: Fix Grafana dashboard datasource references

**Files:**
- Modify: `grafana/provisioning/dashboards/claude-code.json`

- [ ] **Step 1: Remove `__inputs` and `__requires` blocks from the dashboard JSON**

Open `grafana/provisioning/dashboards/claude-code.json`. Remove the `"__inputs"` array and the `"__requires"` array entirely.

The file currently starts like this:

```json
{
  "__inputs": [ ... ],
  "__elements": {},
  "__requires": [ ... ],
  "annotations": { ... },
```

After the edit it should start like this:

```json
{
  "__elements": {},
  "annotations": { ... },
```

No other changes are needed — the panel datasource references already use `{ "type": "loki", "uid": "loki" }` which matches the local provisioned datasource.

- [ ] **Step 2: Validate the JSON is still well-formed**

```bash
python3 -m json.tool grafana/provisioning/dashboards/claude-code.json > /dev/null && echo "JSON valid"
```

Expected: `JSON valid`

- [ ] **Step 3: Restart Grafana and verify the dashboard loads**

```bash
docker compose restart grafana
```

Open http://localhost:3000 → **Dashboards → Claude Code folder → Claude Code** dashboard.

Expected: Dashboard loads without the "datasource not found" or "select datasource" prompts. All panels show either data or "No data" (not errors).

- [ ] **Step 4: Commit**

```bash
git add grafana/provisioning/dashboards/claude-code.json
git commit -m "fix: remove Grafana Cloud datasource references from dashboard JSON"
```

---

## Self-Review

**Spec coverage:**
- [x] Image updates → Task 1
- [x] `claude-env.sh` portability → Task 2
- [x] Loki retention → Task 3
- [x] Prometheus retention → Task 4
- [x] Dashboard `__inputs`/`__requires` fix → Task 6
- [x] `tracesToMetrics` correlation → Task 5
- [x] `derivedFields` logs→traces → Task 5

**Placeholder scan:** No TBDs. All steps include exact commands, expected output, and actual config/code.

**Type consistency:** No application code — all config. File paths and YAML keys are consistent across tasks.

**Known risk:** The `derivedFields` regex assumes OTel logs have `trace_id` as inline JSON. Task 5 Step 3 includes a verification step and a note to adjust if needed.
