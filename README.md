# claude-code-costs

Local observability stack for monitoring [Claude Code](https://claude.ai/code) telemetry via OpenTelemetry. Captures logs, metrics, and traces from Claude Code and visualizes them in Grafana.

## Architecture

```
Claude Code → OTel Collector → Loki        (logs,    30-day retention)
                             → Prometheus   (metrics, 30-day retention)
                             → Tempo        (traces,  72h retention)
                                   ↓
                               Grafana      (visualization + correlation)
```

## Services

| Service | Port(s) | Description |
|---|---|---|
| OTel Collector | `4317` (gRPC), `4318` (HTTP), `8888` (internal metrics) | Receives telemetry from Claude Code and routes to backends |
| Loki | `3100` | Log storage (30-day retention) |
| Prometheus | `9090` | Metrics storage (30-day retention) |
| Tempo | `3200` (HTTP), `4319` (gRPC) | Trace storage (72h retention) |
| Grafana | `3000` | Visualization (login: `admin` / `admin`) |

## Requirements

- [Docker](https://docs.docker.com/get-docker/) with Docker Compose
- [mise](https://mise.jdx.dev/) (optional, for task shortcuts)

## Usage

### 1. Start the stack

```bash
docker compose up -d
```

### 2. Configure and start Claude Code with telemetry

```bash
source ./claude-env.sh
claude
```

The `claude-env.sh` script sets the `OTEL_*` and `CLAUDE_CODE_*` environment variables pointing to `localhost:4317` (gRPC) and `localhost:4318` (HTTP for beta tracing).

By default the endpoint points to `localhost`. To use a remote host (e.g., via Tailscale):

```bash
OTEL_HOST=100.74.255.104 source ./claude-env.sh
claude
```

### 3. Access Grafana

Open [http://localhost:3000](http://localhost:3000) and log in with `admin` / `admin`.

The **Claude Code** dashboard is automatically provisioned with all three datasources (Loki, Prometheus, and Tempo) and bidirectional correlation between them:

- Logs → Traces (via `trace_id` in log lines)
- Traces → Logs
- Traces → Metrics

## Capturing additional content (optional)

Uncomment the lines at the bottom of `claude-env.sh` to capture more data:

```bash
export OTEL_LOG_TOOL_CONTENT=1    # tool content
export OTEL_LOG_TOOL_DETAILS=1    # tool details
export OTEL_LOG_USER_PROMPTS=1    # user prompts
```

> **Warning:** capturing prompts and tool content may include sensitive information in the logs.

## Useful commands

A `mise.toml` is included for convenience. After installing [mise](https://mise.jdx.dev/), trust the config once:

```bash
mise trust
```

Then use the task shortcuts:

```bash
mise run up              # Start the stack (docker compose up -d)
mise run down            # Stop the stack
mise run restart         # Restart all services
mise run ps              # Show container status
mise run logs:collector  # Stream OTel Collector logs
mise run logs:loki       # Stream Loki logs
mise run logs:prometheus # Stream Prometheus logs
mise run logs:tempo      # Stream Tempo logs
mise run logs:grafana    # Stream Grafana logs
```

Or use Docker Compose directly:

```bash
# Stop and remove volumes (deletes all data)
docker compose down -v
```

## Data retention

| Backend | Retention | Configuration |
|---|---|---|
| Loki | 30 days | `loki-config.yaml` → `limits_config.retention_period` |
| Prometheus | 30 days | `docker-compose.yml` → `--storage.tsdb.retention.time` |
| Tempo | 72 hours | `tempo.yaml` → `compactor.compaction.block_retention` |

## Provisioning

- **Datasources:** `grafana/provisioning/datasources/datasources.yaml`
- **Dashboards:** `grafana/provisioning/dashboards/`
- **Main dashboard:** `grafana/provisioning/dashboards/claude-code.json`
- **Loki config:** `loki-config.yaml`
- **Tempo config:** `tempo.yaml`

Dashboard and datasource changes take effect after:

```bash
docker compose restart grafana
```
