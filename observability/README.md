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

## Alerting scaffolding

Grafana alerting provisioning lives in `observability/grafana/provisioning/alerting`.

- `contact-points.yaml` defines email contact points for super-admin notifications.
- `policies.yaml` routes `severity=critical` and `severity=warning` alerts.
- `rules.yaml` provisions the initial collector/exporter/PostgreSQL health rules.

For real production delivery, replace the placeholder recipient values in the Grafana container environment:

- `GRAFANA_ALERT_EMAILS`
- `GRAFANA_ALERT_CRITICAL_EMAILS`

The local stack does not configure SMTP, so the contact points are scaffolding unless Grafana is started with working mail settings.
