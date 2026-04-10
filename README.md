# claude-code-costs

Stack de observabilidade local para monitorar telemetria do [Claude Code](https://claude.ai/code) via OpenTelemetry. Captura logs, métricas e traces do Claude Code e os visualiza no Grafana.

## Arquitetura

```
Claude Code → OTel Collector → Loki       (logs)
                             → Prometheus  (métricas)
                             → Tempo       (traces)
                                   ↓
                               Grafana     (visualização)
```

## Serviços

| Serviço | Porta(s) | Descrição |
|---|---|---|
| OTel Collector | `4317` (gRPC), `4318` (HTTP), `8888` (métricas internas) | Recebe telemetria do Claude Code e roteia para os backends |
| Loki | `3100` | Armazenamento de logs |
| Prometheus | `9090` | Armazenamento de métricas |
| Tempo | `3200` (HTTP), `4319` (gRPC) | Armazenamento de traces |
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

### 3. Acessar o Grafana

Abra [http://localhost:3000](http://localhost:3000) e faça login com `admin` / `admin`.

O dashboard **Claude Code** é provisionado automaticamente com as três datasources (Loki, Prometheus e Tempo).

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

# Derrubar a stack
docker compose down

# Derrubar e remover volumes (apaga todos os dados)
docker compose down -v
```

## Provisionamento

- **Datasources:** `grafana/provisioning/datasources/datasources.yaml`
- **Dashboards:** `grafana/provisioning/dashboards/`
- **Dashboard principal:** `grafana/provisioning/dashboards/claude-code.json`

Alterações nos dashboards entram em vigor com `docker compose restart grafana`.

