# Repository Guidelines

## Project Structure & Module Organization
Configuration lives in `docker/`, split by concern: `data-stores.yml` (MongoDB, Postgres, Kafka, Elasticsearch), `services.yml` (React UI, Backend, Strapi), `tools.yml` (Tuddi, Conduktor), and `reverse-proxy.yml` (Nginx). Public config ships in `docker/config.env` (with `config.env.template` as a reference) while runtime secrets stay in `docker/.env` derived from `.env.template`. Shell helpers in `scripts/` wrap Docker Compose orchestration; `scripts/restore-backup.sh` also seeds MongoDB and Strapi uploads. Keep new assets (e.g., nginx rules, backups) near their consumers to avoid drifting configs.

## Build, Test, and Development Commands
- `./scripts/start.sh` – Ensures `config.env` + `.env`, materializes `app-network`, and runs `docker-compose -f <files> up -d`.
- `./scripts/stop.sh` – Calls `docker-compose ... down` and prunes `app-network` when idle.
- `docker-compose -f docker/services.yml config` – Quick validation when editing compose fragments.
- `docker ps | grep sr-` – Confirm container health after changes; prefer `docker logs <service>` for debugging.

## Coding Style & Naming Conventions
Compose YAML and nginx configs use two-space indentation; keep keys in `snake_case`, services in `kebab-case` (e.g., `backend`). Environment variables stay uppercase with `_` separators (`BACKEND_VERSION`). Bash helpers follow `set -euo pipefail` + descriptive functions when expanded; prefer `shellcheck` locally before committing. Scripts should accept future compose files by editing the `COMPOSE_FILES` array only.

## Testing Guidelines
There is no unit-test harness; validation means running the stack. After any change: `./scripts/start.sh`, hit `http://simonrowe.localhost:8080`, and spot-check critical ports (3000, 8081, 1337, 3002). When touching data services, verify persistence by restarting containers and ensuring named volumes (`mongodb_data`, `tududi_db`, etc.) retain state. Document manual test notes in PRs so others can reproduce.

## Commit & Pull Request Guidelines
History uses Conventional Commit prefixes (`chore: ...`). Continue with `feat:`, `fix:`, or `docs:` plus a concise imperative summary (≤72 chars). Each PR should include: purpose, key files touched, manual test evidence (commands + results), and any required host/secret updates. Link tracking issues when available and attach screenshots for UI-facing changes behind the reverse proxy.

## Security & Configuration Tips
Never commit populated `.env`; share secrets through secure channels. Versioned overrides belong in `docker/config.env`. When adding hosts or TLS assets, reference them in `README.md` and `docker/nginx/nginx.conf`. Validate new domains via `/etc/hosts` and keep ports scoped to the `app-network` unless exposure is intentional. Clean up local volumes with `docker volume rm` only when you are sure data is expendable.
