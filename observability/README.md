# Observability Stack

The repository includes a local Grafana stack for logs, traces, metrics, dashboards, and exporters.

## Default services

Running `docker compose up` brings up:

- OpenTelemetry Collector
- Tempo
- Loki
- Alloy
- Prometheus
- Grafana
- PostgreSQL exporter

## Host-level exporters

`node-exporter` and `cadvisor` are included behind the `host-observability` profile because they are most reliable on a Linux Docker host.

Enable them with:

```sh
docker compose --profile host-observability up
```

When the profile is enabled, Prometheus scrapes host, container, and PostgreSQL telemetry, and Grafana loads the provisioned infrastructure and PostgreSQL dashboards automatically.
