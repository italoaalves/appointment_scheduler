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

## Kamal staging accessories

`config/deploy.yml` now wires the staging VPS to run the same observability stack with Kamal accessories:

- OpenTelemetry Collector
- Tempo
- Loki
- Alloy
- Prometheus
- Grafana
- `node-exporter`
- `cadvisor`
- `postgres-exporter`

The Rails app is configured to send OTLP data to `http://otel-collector:4318`, and staging database connections now prefer the Kamal accessory env vars (`DB_HOST`, `DB_USER`, `DB_PORT`, `APPOINTMENT_SCHEDULER_DATABASE_PASSWORD`) before falling back to credentials.

For staging, Grafana and Prometheus are only published on localhost on the VPS:

- Grafana: `127.0.0.1:3001`
- Prometheus: `127.0.0.1:9090`

Reach them with an SSH tunnel, for example:

```sh
ssh -p 22022 -L 3001:127.0.0.1:3001 -L 9090:127.0.0.1:9090 root@129.121.50.44
```

Then open:

- `http://localhost:3001`
- `http://localhost:9090`

Boot accessories explicitly with Kamal before or alongside the app deploy:

```sh
bin/kamal accessory boot db
bin/kamal accessory boot otel-collector
bin/kamal accessory boot tempo
bin/kamal accessory boot loki
bin/kamal accessory boot alloy
bin/kamal accessory boot prometheus
bin/kamal accessory boot node-exporter
bin/kamal accessory boot cadvisor
bin/kamal accessory boot postgres-exporter
bin/kamal accessory boot grafana
```

For the later production cutover, keep the same accessory topology but remove Grafana anonymous admin access and replace the placeholder alert recipient env values with the real super-admin destinations.
