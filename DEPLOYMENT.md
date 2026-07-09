# Getsa Backend Deployment

This deployment keeps FastAPI and Postgres on one small DigitalOcean droplet via Docker Compose.

## DigitalOcean droplet

Manual console settings:

- Image: Ubuntu 24.04 LTS x64
- Size: Basic, 1GB RAM / 1 vCPU
- Region: choose the closest region to users, such as BLR1 for India
- Authentication: SSH key
- Firewall: allow inbound 22, 80, and 443 only; deny all other inbound traffic

## Droplet setup

```sh
curl -fsSL https://get.docker.com | sh
apt install docker-compose-plugin nginx -y
docker --version
docker compose version
```

Copy or clone this repo onto the droplet, then create `.env` on the droplet only:

```sh
DATABASE_URL=postgresql://forma:<POSTGRES_PASSWORD>@db:5432/forma
JWT_SECRET_KEY=<GENERATED_STRONG_SECRET>
POSTGRES_PASSWORD=<GENERATED_STRONG_PASSWORD>
```

Start the stack:

```sh
docker compose up -d --build
docker compose ps
docker compose exec api alembic upgrade head
```

## Nginx HTTP proxy

Use this server block before TLS is available:

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Once a domain points to the droplet, install Certbot and enable HTTPS:

```sh
apt install certbot python3-certbot-nginx -y
certbot --nginx -d yourdomain.com
```

Do not send production passwords or JWTs over plain HTTP after the domain is connected.
