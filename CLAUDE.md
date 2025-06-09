# Docker Compose Environment

This is a Docker Compose environment for running a website.

## Project Structure
- Docker Compose setup with multiple files in `docker/` directory
- Docker compose files:
  - `data-stores.yml` - for things like mongo, kafka, elastic search
  - `observability.yml` - for things like grafana cloud
  - `services.yml` - for any of the services that I have built
- Environment configuration:
  - `.env` - contains secrets (not committed)
  - `.env.template` - template for environment variables

## Development Commands
- `cd docker && ./start.sh` - Start the environment
- `cd docker && ./stop.sh` - Stop the environment

## Setup
1. Copy `.env.template` to `.env` in the docker directory
2. Update `.env` with your actual credentials
3. Run `./start.sh` to start services

## Notes
- Environment files contain sensitive data and should not be committed
- MongoDB runs on port 27017 with authentication enabled