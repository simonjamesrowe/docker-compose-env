# Docker Compose Environment

This is a Docker Compose environment for running a personal website (www.simonrowe.dev) and development tools.

## Project Structure
- Docker Compose setup with multiple files in `docker/` directory
- Scripts in `scripts/` directory in project root
- Docker compose files:
  - `data-stores.yml` - MongoDB, Kafka, Elasticsearch, Kibana, PostgreSQL
  - `tools.yml` - Third party tools (Tuddi todo app, Conduktor Kafka UI)
  - `reverse-proxy.yml` - Nginx reverse proxy for routing
  - `services.yml` - Custom services (Strapi CMS, React UI, Backend)
- Environment configuration:
- `config.env` - tracked non-secret configuration
- `config.env.template` - template for config overrides
- `.env` - contains secrets (not committed)
- `.env.template` - template for secrets
- Nginx configuration in `docker/nginx/` directory

## Development Commands

### Core Environment Management
- `./scripts/start.sh` - Start the entire Docker Compose environment
- `./scripts/stop.sh` - Stop all services and cleanup (includes stopping Pinggy tunnel if running)
- `./scripts/backup.sh` - Create timestamped backup of MongoDB and Strapi uploads to `~/backups/`
- `./scripts/restore-backup.sh` - Restore from backup (auto-discovers latest or accepts custom path)

### Quick Reference Commands
```bash
# Validate all compose files
docker-compose -f docker/data-stores.yml -f docker/tools.yml -f docker/services.yml -f docker/reverse-proxy.yml config

# View logs for a specific service
docker logs <service-name>
docker logs -f <service-name>  # Follow mode

# Check container status
docker ps
docker ps -a  # Include stopped containers

# Inspect service details
docker inspect <container-name>

# Network debugging
docker network inspect app-network
docker volume ls
docker volume inspect <volume-name>

# Connect to MongoDB
docker exec -it mongodb mongosh -u root -p <password>

# Access Kafka topics
docker exec -it kafka kafka-topics --list --bootstrap-server localhost:9092
```

## Setup
1. Copy `.env.template` to `.env` in the docker directory
   ```bash
   cp docker/.env.template docker/.env
   ```
2. Edit `docker/.env` with your actual credentials and review `docker/config.env` (copy `config.env.template` if you need a clean starting point).
   - MongoDB credentials
   - Tuddi credentials
   - Strapi JWT secret
   - SendGrid API keys
   - Pinggy auth token (optional, only if enabling PINGGY_ENABLED)
   - Service versions (or use `latest`)
3. Ensure Docker images are available:
   - Pull from GHCR: `docker login ghcr.io` (requires GitHub token)
   - Or build locally from source repositories
4. Run `./scripts/start.sh` to start all services
5. Access services via configured domains (see Service URLs below)

## Application Architecture

This environment hosts a complete personal website ecosystem with the following components:

### Core Services

**Strapi CMS** (Headless CMS)
- Repository: `/Users/simonrowe/workspace/simonjamesrowe/strapi-cms`
- Image: `ghcr.io/simonjamesrowe/strapi-cms:${STRAPI_VERSION}` (default: v0.1.4-arm64)
- Version: Strapi v3.1.4 (Note: EOL, upgrade planned)
- Port: 1337 (container), accessible via cms.simonrowe.dev
- Purpose: Content management for blogs, jobs, skills, profile data
- APIs: GraphQL and REST
- Content Types: blogs, jobs, skills, profile, tags, social-media, tour-steps
- Database: MongoDB via mongoose connector
- Volumes: `strapi_uploads` for `/app/public/uploads` (media files)

**React UI** (Frontend)
- Repository: `/Users/simonrowe/workspace/simonjamesrowe/react-ui`
- Image: `ghcr.io/simonjamesrowe/react-ui:${REACT_UI_VERSION}` (default: v0.4.6-arm64)
- Tech Stack: React 16.13.1, TypeScript, Redux, Nginx
- Port: 80 (container), 3000 (host), accessible via simonrowe.dev
- Purpose: Personal portfolio/resume SPA
- Features: Jobs history, Skills showcase, Blog posts, Interactive tours
- UI Libraries: Material-UI v4, React Bootstrap
- Backend API: Calls api.simonrowe.dev:8080 (routed through nginx reverse proxy)

**Backend Modulith** (Unified backend)
- Repository: `/Users/simonrowe/workspace/simonjamesrowe/backend-modulith`
- Tech Stack: Java 21, Spring Boot 3.3.5, Gradle
- Image: `ghcr.io/simonjamesrowe/backend:${BACKEND_VERSION}` (default: 0.0.30-arm64)
- Ports: 8080 (container), 8081 (host via compose)
- Responsibilities: REST API surface, webhook ingestion, Kafka publishing/consumption, search indexing, scheduled sync jobs
- Integrations: Strapi CMS (`http://strapi-cms:1337`), Kafka (`kafka:9092`), Elasticsearch (`http://elasticsearch:9200`), SendGrid email
- Architecture: Modular monolith with clean architecture modules (`modules/backend`, `modules/model`, `modules/component-test`)

### Supporting Infrastructure

**Data Stores**
- **MongoDB** - Port 27017, authentication enabled, used by Strapi CMS
- **Kafka** - Port 9092 (internal), 29092 (host), event streaming between services
- **Zookeeper** - Port 2181, Kafka coordination
- **Elasticsearch** - Port 9200 (HTTP), 9300 (transport), full-text search indexing

**Tools**
- **Tuddi** - Todo application, port 3002
- **Conduktor** - Kafka management UI, port 8088

**Reverse Proxy**
- **Nginx** - Port 8080 (host) to 80 (container), routes traffic to all services based on domain names

**Public Tunneling (Optional)**
- **Pinggy** - SSH tunnel that creates HTTPS reverse proxy to localhost:8080 (optional, controlled via PINGGY_ENABLED)

## Data Flow

1. **Content Management**: Content creators → Strapi CMS → MongoDB
2. **Content Publishing**: Strapi Webhook → Backend → Kafka (`cms-events`)
3. **Search Indexing**: Kafka → Backend → Elasticsearch
4. **Frontend Display**: React UI → Backend → Strapi CMS / Elasticsearch
5. **Email Notifications**: Backend → SendGrid

## Service URLs

### Local Access via Nginx (Reverse Proxy)

All services are accessible through Nginx reverse proxy on port 8080:

- **Main Website**: http://simonrowe.dev:8080 or http://simonrowe.localhost:8080
  - Routes to: React UI (container port 80)
- **Backend API**: http://api.simonrowe.dev:8080 or http://api.simonrowe.localhost:8080
  - Routes to: Backend (container port 8080)
- **Strapi CMS**: http://cms.simonrowe.dev:8080 or http://cms.simonrowe.localhost:8080
  - Routes to: Strapi CMS (container port 1337)
- **Tuddi Todo App**: http://todos.simonrowe.dev:8080 or http://todos.simonrowe.localhost:8080
  - Routes to: Tuddi (container port 3002)
- **Conduktor Kafka UI**: http://conduktor.simonrowe.dev:8080 or http://conduktor.simonrowe.localhost:8080
  - Routes to: Conduktor (container port 8080)

### Public Access via Pinggy (Optional HTTPS Tunnel)

Services can be exposed through a secure HTTPS tunnel via Pinggy when enabled:

**Enabling Pinggy:**
1. Sign up at https://pinggy.io/
2. Obtain your Pinggy authentication token
3. Add the token to `docker/.env` as `PINGGY_AUTH_TOKEN=<your_token>`
4. Set `PINGGY_ENABLED=true` in `docker/config.env` (default is `false`)
5. Run `./scripts/start.sh` - the Pinggy tunnel will start automatically

**Tunnel Details:**
- The SSH tunnel runs in the background and tunnels `localhost:8080` (nginx reverse proxy) through Pinggy
- All requests are routed through the Pinggy HTTPS tunnel to your local nginx, which then routes to the appropriate service
- Pinggy automatically assigns you a unique domain (e.g., `abc123.pinggy.io`) that maps to your services
- To stop the tunnel, run `./scripts/stop.sh` which will clean up the SSH process

**Note:** You can configure custom domains in the Pinggy dashboard if you have a wildcard domain set up

**Direct Access** (bypassing Nginx):
- React UI: http://localhost:3000
- Backend API: http://localhost:8081
- Strapi CMS: http://localhost:1337
- Tuddi: http://localhost:3002
- Conduktor: http://localhost:8088
- MongoDB: localhost:27017
- Kafka: localhost:29092 (external), kafka:9092 (internal)
- Elasticsearch: http://localhost:9200
- Zookeeper: localhost:2181

**Note**: For domain-based routing to work locally:
- **`.dev` domains** require `/etc/hosts` entries:
  ```
  127.0.0.1 simonrowe.dev www.simonrowe.dev
  127.0.0.1 api.simonrowe.dev
  127.0.0.1 cms.simonrowe.dev
  127.0.0.1 todos.simonrowe.dev
  127.0.0.1 conduktor.simonrowe.dev
  ```
- **`.localhost` domains** work automatically (no hosts file needed) - modern browsers resolve these to `127.0.0.1` by default

## Network
- All services run on `app-network` for inter-service communication
- Services communicate directly via container names
- External access via Nginx reverse proxy

## Environment Variables

- `docker/config.env` (versioned) holds non-secret values such as service versions, URLs (`API_URL`, `CMS_URL`), database names, Kafka bootstrap servers, Kibana URL, `PINGGY_ENABLED`, etc.
- `docker/.env` (gitignored) stores all secrets and credentials:
  - `MONGO_ROOT_USERNAME`, `MONGO_ROOT_PASSWORD`
  - `POSTGRES_USER`, `POSTGRES_PASSWORD`
  - `TUDUDI_USER_EMAIL`, `TUDUDI_USER_PASSWORD`, `TUDUDI_SESSION_SECRET`
  - `CONDUKTOR_ADMIN_EMAIL`, `CONDUKTOR_ADMIN_PASSWORD`
  - `STRAPI_ADMIN_JWT_SECRET`
  - `SENDGRID_API_KEY`, `SENDGRID_FROM_EMAIL`, `SENDGRID_TO_EMAIL`
  - `ELASTICSEARCH_USERNAME`, `ELASTICSEARCH_PASSWORD`
  - `PINGGY_AUTH_TOKEN` (only needed if `PINGGY_ENABLED=true`)

**URL Configuration:**
- **Internal URLs** (backend-to-backend): Services use Docker container names for direct communication
  - Backend → Strapi CMS: `http://strapi-cms:1337`
  - Backend → Kafka: `kafka:9092`
  - Backend → Elasticsearch: `http://elasticsearch:9200`
- **External URLs** (browser-to-backend): React UI uses domain-based URLs routed through nginx
  - React UI → Backend: `http://api.simonrowe.dev:8080` (proxied to backend:8080)

## Backup and Restore Workflows

### Creating a Backup

To create a new backup of MongoDB database and Strapi uploads:

```bash
./scripts/backup.sh
```

This creates a compressed archive at `~/backups/strapi-backup-YYYYMMDD_HHMMSS.tar.gz` containing:
- MongoDB dump in BSON format
- Strapi uploaded files (images, PDFs, etc.)

The backup script automatically:
- Creates the `~/backups/` directory if it doesn't exist
- Compresses both databases and files into a single tar.gz
- Cleans up temporary staging directories
- Shows progress and completion messages

### Restoring from Backup

To restore from a backup:

```bash
# Restore from latest backup (auto-discovers)
./scripts/restore-backup.sh

# Restore from specific archive
./scripts/restore-backup.sh ~/backups/strapi-backup-20250101_120000.tar.gz

# Restore from specific directory (for older backup format)
./scripts/restore-backup.sh ~/Downloads/sjr-backup-31Oct2021/
```

The restore script will:
1. Extract the backup archive to a temporary staging directory
2. Restore MongoDB collections to the `strapi` database
3. Copy all upload files to the Strapi uploads volume
4. Set proper file permissions in containers
5. Clean up temporary staging directories

**Note:** Ensure the environment is running before restoring (`./scripts/start.sh`). The MongoDB container must be healthy for imports to succeed.

## Related Repositories

- **Strapi CMS**: `/Users/simonrowe/workspace/simonjamesrowe/strapi-cms`
- **React UI**: `/Users/simonrowe/workspace/simonjamesrowe/react-ui`
- **Backend Modulith**: `/Users/simonrowe/workspace/simonjamesrowe/backend-modulith`

## Architecture & Design Patterns

### Environment Management
- **Config Split**: `config.env` (versioned, non-secret) + `.env` (gitignored, secrets)
- **Template Pattern**: Both files have `.template` versions for easy setup
- **Helper Script**: `scripts/lib/env.sh` provides `load_env_files()` to ensure both files exist
- **Version Pinning**: Services use ARM64-compatible tags (e.g., `v0.1.4-arm64`) for consistency
- **Override Pattern**: Compose files use `${VAR:-default}` to allow env overrides with sensible defaults

### Network Architecture
- **External Network**: `app-network` is created before compose up for inter-service communication
- **Container Names**: Services communicate internally via container names (e.g., `strapi-cms:1337`)
- **Reverse Proxy**: Nginx routes by Host header on port 8080
- **Network Isolation**: Services don't expose ports directly except through nginx or specific host mappings

### Data Persistence
- **Named Volumes Only**: All data uses Docker named volumes (no host filesystem mounts)
- **Volume List**: See "Docker Volumes" section below for complete list
- **Backup Strategy**: Separate backup/restore scripts handle MongoDB dumps and file exports
- **Database Initialization**: MongoDB uses authentication; credentials from environment

### Service Dependencies
- Kafka depends on Zookeeper (coordination)
- Backend depends on Kafka, Elasticsearch, Strapi (startup order matters)
- Strapi depends on MongoDB (database required before startup)
- All services can restart independently due to network design

### Event-Driven Architecture
- Strapi publishes content changes to Kafka `cms-events` topic
- Backend consumes events and triggers search indexing
- Elasticsearch maintains full-text search indices
- Async communication prevents tight coupling between services

### Code Architecture (Backend)
- **Clean Architecture Pattern**: Core → DataProviders → Entrypoints
- **Modular Monolith**: Single codebase with distinct modules
- **Module Structure**: `modules/backend`, `modules/model`, `modules/component-test`
- **REST Surface**: All external APIs exposed through REST endpoints

## Troubleshooting

### Common Issues

**Port Already in Use:**
- Port 8080: Nginx reverse proxy
- Port 3000: React UI dev server
- Port 8081: Backend API
- Port 1337: Strapi CMS
- Port 27017: MongoDB
- Port 9092/29092: Kafka
- Port 9200: Elasticsearch
- Port 5601: Kibana
- Port 5432: PostgreSQL

Use `lsof -i :<port>` to find conflicting processes.

**MongoDB Won't Start:**
- Check volume `mongodb_data` exists: `docker volume ls`
- Verify credentials in `.env` match MONGO_INITDB_ROOT_USERNAME/PASSWORD
- Check logs: `docker logs mongodb`

**Services Can't Connect:**
- Verify app-network exists: `docker network ls`
- Check container names: `docker ps`
- Test connectivity: `docker exec <container> ping <target-service>`

**Pinggy Tunnel Not Working:**
- Verify PINGGY_ENABLED=true in config.env
- Check token: `echo $PINGGY_AUTH_TOKEN`
- View tunnel process: `ps aux | grep ssh`
- Check PID file: `cat /tmp/pinggy-tunnel.pid`

## Notes
- Environment files contain sensitive data and should not be committed
- All services use Docker volumes for persistent data (no host filesystem mounts)
- Event-driven architecture using Kafka for async communication between services
- Clean architecture pattern in backend services (core → dataproviders → entrypoints)

## Docker Volumes

The following named volumes are used for persistent data:

**Data Stores:**
- `mongodb_data` - MongoDB database files
- `zookeeper_data` - Zookeeper data
- `zookeeper_log` - Zookeeper transaction logs
- `kafka_data` - Kafka message logs
- `elasticsearch_data` - Elasticsearch indices

**Tools:**
- `tududi_db` - Tuddi todo app database
- `conduktor_data` - Conduktor configuration and state

**Services:**
- `strapi_uploads` - Strapi CMS uploaded media files (`/app/public/uploads`)
