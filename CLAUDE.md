# Docker Compose Environment

This is a Docker Compose environment for running a website and development tools.

## Project Structure
- Docker Compose setup with multiple files in `docker/` directory
- Scripts moved to `scripts/` directory in project root
- Docker compose files:
  - `data-stores.yml` - for things like mongo, kafka, elastic search
  - `tools.yml` - for third party tools (tuddi todo app)
  - `reverse-proxy.yml` - nginx reverse proxy for routing
  - `observability.yml` - for things like grafana cloud
  - `services.yml` - for any of the services that I have built
- Environment configuration:
  - `.env` - contains secrets (not committed)
  - `.env.template` - template for environment variables
- Nginx configuration in `docker/nginx/` directory

## Development Commands
- `./scripts/start.sh` - Start the environment
- `./scripts/stop.sh` - Stop the environment

## Setup
1. Copy `.env.template` to `.env` in the docker directory
2. Update `.env` with your actual credentials (including tuddi variables)
3. Run `./scripts/start.sh` to start services

## Services
- **MongoDB** - runs on port 27017 with authentication enabled
- **Tuddi** - todo application accessible via todos.simonrowe.dev (port 3002)
- **Nginx** - reverse proxy on port 80 routing todos.simonrowe.dev to tuddi

## Network
- All services run on `app-network` for inter-service communication
- MongoDB and tuddi can communicate directly via container names

## Notes
- Environment files contain sensitive data and should not be committed
- All services use Docker volumes for persistent data (no host filesystem mounts)
- Nginx routes todos.simonrowe.dev to the tuddi container