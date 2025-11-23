# Docker Compose Environment

This is a Docker Compose environment for running a personal website (www.simonrowe.dev) and development tools.

## Project Structure
- Docker Compose setup with multiple files in `docker/` directory
- Scripts in `scripts/` directory in project root
- Docker compose files:
  - `data-stores.yml` - MongoDB, Kafka, Elastiactuacsearch
  - `tools.yml` - Third party tools (Tuddi todo app)
  - `reverse-proxy.yml` - Nginx reverse proxy for routing
  - `observability.yml` - Grafana Cloud and monitoring tools
  - `services.yml` - Custom services (Strapi CMS, React UI, Backend)
- Environment configuration:
- `config.env` - tracked non-secret configuration
- `config.env.template` - template for config overrides
- `.env` - contains secrets (not committed)
- `.env.template` - template for secrets
- Nginx configuration in `docker/nginx/` directory

## Development Commands
- `./scripts/start.sh` - Start the environment
- `./scripts/stop.sh` - Stop the environment
- `./scripts/restore-backup.sh` - Restore MongoDB and Strapi uploads from backup

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
- Image: `ghcr.io/simonjamesrowe/strapi-cms:0.0.32`
- Version: Strapi v3.1.4 (Note: EOL, upgrade planned)
- Port: 1337 (container), accessible via cms.simonrowe.dev
- Purpose: Content management for blogs, jobs, skills, profile data
- APIs: GraphQL and REST
- Content Types: blogs, jobs, skills, profile, tags, social-media, tour-steps
- Database: MongoDB via mongoose connector
- Volumes: `strapi_uploads` for `/app/public/uploads` (media files)

**React UI** (Frontend)
- Repository: `/Users/simonrowe/workspace/simonjamesrowe/react-ui`
- Image: `ghcr.io/simonjamesrowe/react-ui:0.0.73`
- Tech Stack: React 16.13.1, TypeScript, Redux, Nginx
- Port: 80 (container), 3000 (host), accessible via simonrowe.dev
- Purpose: Personal portfolio/resume SPA
- Features: Jobs history, Skills showcase, Blog posts, Interactive tours
- UI Libraries: Material-UI v4, React Bootstrap
- Backend API: Calls api.simonrowe.dev:8080 (routed through nginx reverse proxy)

**Backend Modulith** (Unified backend)
- Repository: `/Users/simonrowe/workspace/simonjamesrowe/backend-modulith`
- Tech Stack: Java 21, Spring Boot 3.3.5, Gradle
- Image: `ghcr.io/simonjamesrowe/backend:latest`
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

## Backup and Restore

### Restoring from Backup

To restore MongoDB database and Strapi uploads from a backup:

1. Ensure the backup exists at `~/Downloads/sjr-backup-31Oct2021/`
2. Start the environment: `./scripts/start.sh`
3. Run the restore script: `./scripts/restore-backup.sh`
4. Restart Strapi to apply changes: `docker restart strapi-cms`

The restore script will:
- Restore MongoDB collections to the `strapi` database
- Copy all upload files to the Strapi uploads volume
- Set proper permissions on uploaded files

**Backup Structure:**
- `~/Downloads/sjr-backup-31Oct2021/cms-production/cms-production/` - MongoDB dump (BSON format)
- `~/Downloads/sjr-backup-31Oct2021/files/` - Strapi uploaded files (images, PDFs, etc.)

## Related Repositories

- **Strapi CMS**: `/Users/simonrowe/workspace/simonjamesrowe/strapi-cms`
- **React UI**: `/Users/simonrowe/workspace/simonjamesrowe/react-ui`
- **Backend Modulith**: `/Users/simonrowe/workspace/simonjamesrowe/backend-modulith`

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
