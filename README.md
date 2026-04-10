# claude-code-costs

Stack de observabilidade local para monitorar telemetria do [Claude Code](https://claude.ai/code) via OpenTelemetry. Captura logs, métricas e traces do Claude Code e os visualiza no Grafana.

## Arquitetura

```
Claude Code → OTel Collector → Loki       (logs,    retenção 30 dias)
                             → Prometheus  (métricas, retenção 30 dias)
                             → Tempo       (traces,   retenção 72h)
                                   ↓
                               Grafana     (visualização + correlação)
```

## Serviços

| Serviço | Porta(s) | Descrição |
|---|---|---|
| OTel Collector | `4317` (gRPC), `4318` (HTTP), `8888` (métricas internas) | Recebe telemetria do Claude Code e roteia para os backends |
| Loki | `3100` | Armazenamento de logs (retenção 30 dias) |
| Prometheus | `9090` | Armazenamento de métricas (retenção 30 dias) |
| Tempo | `3200` (HTTP), `4319` (gRPC) | Armazenamento de traces (retenção 72h) |
| Grafana | `3000` | Visualização (login: `admin` / `admin`) |

## Requisitos

- [Docker](https://docs.docker.com/get-docker/) com Docker Compose

## Uso

### 1. Subir a stack

```bash
docker compose up -d
```

### 2. Configurar e iniciar o Claude Code com telemetria

```bash
source ./claude-env.sh
claude
```

O script `claude-env.sh` configura as variáveis de ambiente `OTEL_*` e `CLAUDE_CODE_*` apontando para `localhost:4317` (gRPC) e `localhost:4318` (HTTP para beta tracing).

Por padrão o endpoint aponta para `localhost`. Para usar um host remoto (ex: via Tailscale):

```bash
OTEL_HOST=100.74.255.104 source ./claude-env.sh
claude
```

### 3. Acessar o Grafana

Abra [http://localhost:3000](http://localhost:3000) e faça login com `admin` / `admin`.

O dashboard **Claude Code** é provisionado automaticamente com as três datasources (Loki, Prometheus e Tempo) e correlação bidirecional entre elas:

- Logs → Traces (via `trace_id` nos logs)
- Traces → Logs
- Traces → Métricas

## Captura de conteúdo adicional (opcional)

Descomente as linhas no final de `claude-env.sh` para capturar mais dados:

```bash
export OTEL_LOG_TOOL_CONTENT=1    # conteúdo das ferramentas
export OTEL_LOG_TOOL_DETAILS=1    # detalhes das ferramentas
export OTEL_LOG_USER_PROMPTS=1    # prompts do usuário
```

> **Atenção:** capturar prompts e conteúdo de ferramentas pode incluir informações sensíveis nos logs.

## Comandos úteis

```bash
# Ver logs de um serviço
docker compose logs -f otel-collector
docker compose logs -f loki
docker compose logs -f prometheus
docker compose logs -f tempo
docker compose logs -f grafana

# Status dos containers
docker compose ps

# Derrubar a stack
docker compose down

# Derrubar e remover volumes (apaga todos os dados)
docker compose down -v
```

## Retenção de dados

| Backend | Retenção | Configuração |
|---|---|---|
| Loki | 30 dias | `loki-config.yaml` → `limits_config.retention_period` |
| Prometheus | 30 dias | `docker-compose.yml` → `--storage.tsdb.retention.time` |
| Tempo | 72 horas | `tempo.yaml` → `compactor.compaction.block_retention` |

## Provisionamento

- **Datasources:** `grafana/provisioning/datasources/datasources.yaml`
- **Dashboards:** `grafana/provisioning/dashboards/`
- **Dashboard principal:** `grafana/provisioning/dashboards/claude-code.json`
- **Config Loki:** `loki-config.yaml`
- **Config Tempo:** `tempo.yaml`

Alterações nos dashboards ou datasources entram em vigor com:

```bash
docker compose restart grafana
```
