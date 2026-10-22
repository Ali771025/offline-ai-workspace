# Private configuration

Create `.env` locally; never publish generated credentials or service backups. Values such as `CHANGE_ME` in templates are placeholders and must be replaced with fresh secrets. Review every compose interpolation before deployment.

The base compose expects POSTGRES_HOST, POSTGRES_PORT, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB, REDIS_HOST, REDIS_PORT, REDIS_PASSWORD, QDRANT_HOST, QDRANT_PORT, SERVER_IP, LITELLM_MASTER_KEY, LITELLM_SALT_KEY and WEBUI_SECRET_KEY. The full definition additionally expects POSTGRES_IMAGE, REDIS_IMAGE and QDRANT_IMAGE, and supplies database/vector endpoints on its own Docker network. Obtain compatible container images and models separately.

Loopback and Docker service names are examples of local topology. Use firewall rules and appropriate authentication/TLS for the intended deployment. Scripts can modify host configuration and restore data; read them before running them. This source publication has not been deployed or tested.

## Select one service topology

The supplied reverse-proxy source targets `gitea`, which exists in `docker-compose.full.yml`. The smaller compose definition uses `forgejo` instead. Before using the smaller topology, adapt its Git upstream/service name consistently. These alternatives are retained as integration source; this publication is not a verified one-command appliance.
