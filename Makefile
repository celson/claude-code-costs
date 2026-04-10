.PHONY: up down restart logs-collector logs-loki logs-prometheus logs-tempo logs-grafana ps env

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

ps:
	docker compose ps

logs-collector:
	docker compose logs -f otel-collector

logs-loki:
	docker compose logs -f loki

logs-prometheus:
	docker compose logs -f prometheus

logs-tempo:
	docker compose logs -f tempo

logs-grafana:
	docker compose logs -f grafana

env:
	source ./claude-env.sh
