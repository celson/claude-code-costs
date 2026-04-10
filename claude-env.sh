#!/usr/bin/env bash
# source ./claude-env.sh antes de rodar o claude

OTEL_HOST="${OTEL_HOST:-localhost}"

export OTEL_EXPORTER_OTLP_ENDPOINT="http://${OTEL_HOST}:4317"
export OTEL_EXPORTER_OTLP_PROTOCOL="grpc"

export CLAUDE_CODE_ENABLE_TELEMETRY=1
export CLAUDE_CODE_OTEL_FLUSH_TIMEOUT_MS=1000

export OTEL_LOGS_EXPORTER="otlp"
export OTEL_METRICS_EXPORTER="otlp"
export OTEL_TRACES_EXPORTER="otlp"

export OTEL_LOGS_EXPORT_INTERVAL=1000
export OTEL_METRIC_EXPORT_INTERVAL=1000

export BETA_TRACING_ENDPOINT="http://${OTEL_HOST}:4318"
export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1
export ENABLE_BETA_TRACING_DETAILED=1

# Opcional para capturar mais conteúdo:
# export OTEL_LOG_TOOL_CONTENT=1
# export OTEL_LOG_TOOL_DETAILS=1
# export OTEL_LOG_USER_PROMPTS=1

echo "✅ Variáveis de ambiente do Claude Code OTEL configuradas."
echo "   Agora rode: claude"
