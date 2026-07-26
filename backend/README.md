# Inpenso Shared Trip Spending API

Plain PHP 8.1+ REST backend for shared trip expense tracking. Designed for easy deployment on shared Apache/Nginx hosting with SQLite by default.

## Requirements

- PHP 8.1+
- PDO with `sqlite` (default) or `mysql`
- Apache with `mod_rewrite` **or** Nginx

## Quick start (local)

```bash
cd backend
cp .env.example .env
php scripts/migrate.php
php -S localhost:8080 -t public
curl http://localhost:8080/api/health
```

## Environment

Copy `.env.example` to `.env` and adjust as needed.

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_ENV` | `production` | Environment name |
| `APP_DEBUG` | `false` | Show detailed errors |
| `DB_DRIVER` | `sqlite` | `sqlite` or `mysql` |
| `SQLITE_PATH` | `storage/database.sqlite` | SQLite file path |
| `DB_HOST` | `127.0.0.1` | MySQL host |
| `DB_PORT` | `3306` | MySQL port |
| `DB_DATABASE` | `inpenso` | MySQL database |
| `DB_USERNAME` | `root` | MySQL user |
| `DB_PASSWORD` | | MySQL password |
| `CORS_ORIGINS` | `*` | Comma-separated allowed origins |

## Deploy on Apache (shared hosting)

1. Upload the `backend/` folder to your host.
2. Point the site document root to `backend/public/`.
3. Ensure `storage/` is writable by PHP (`chmod 775 storage`).
4. Run `php scripts/migrate.php` once (SSH or host panel cron).
5. Copy `.env.example` to `.env` if you need MySQL or custom settings.

If you cannot change the document root, use the included root `.htaccess` to forward requests into `public/`.

### Apache virtual host example

```apache
<VirtualHost *:80>
    ServerName api.example.com
    DocumentRoot /var/www/inpenso/backend/public

    <Directory /var/www/inpenso/backend/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

## Deploy on Nginx

```nginx
server {
    listen 80;
    server_name api.example.com;
    root /var/www/inpenso/backend/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
```

Run migrations after deploy:

```bash
php /var/www/inpenso/backend/scripts/migrate.php
```

## Authentication

Register once per device/user with a display name. Store the returned `api_token` securely on the client.

Send the token on every authenticated request using either header:

```
Authorization: Bearer YOUR_API_TOKEN
```

or

```
X-API-Token: YOUR_API_TOKEN
```

## Response format

Success:

```json
{ "ok": true, "data": { ... } }
```

Error:

```json
{ "ok": false, "error": "Message" }
```

## API examples

Replace `BASE` and `TOKEN` below.

```bash
BASE=http://localhost:8080
TOKEN=your_api_token_here
```

### Health check

```bash
curl "$BASE/api/health"
```

### Register

```bash
curl -X POST "$BASE/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"display_name":"Alex"}'
```

### Create trip

```bash
curl -X POST "$BASE/api/trips" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Barcelona 2026","currency":"EUR","start_date":"2026-07-01","end_date":"2026-07-10"}'
```

### Join trip

```bash
curl -X POST "$BASE/api/trips/join" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"invite_code":"ABC123"}'
```

### List my trips

```bash
curl "$BASE/api/trips" \
  -H "Authorization: Bearer $TOKEN"
```

### Trip detail (members, expenses, balances)

```bash
curl "$BASE/api/trips/1" \
  -H "Authorization: Bearer $TOKEN"
```

Balances return each member's `paid`, `owed`, and `net` amounts. Positive `net` means others owe that member; negative means they owe the group.

### Add expense (equal split)

```bash
curl -X POST "$BASE/api/trips/1/expenses" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Dinner","amount":90.00,"paid_by_member_id":1}'
```

### Add expense (custom split map)

```bash
curl -X POST "$BASE/api/trips/1/expenses" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Hotel","amount":200.00,"paid_by_member_id":1,"split":{"1":100,"2":100}}'
```

Split keys are `trip_members.id` values and must sum to the expense amount.

### List expenses

```bash
curl "$BASE/api/trips/1/expenses" \
  -H "Authorization: Bearer $TOKEN"
```

### Delete expense

```bash
curl -X DELETE "$BASE/api/trips/1/expenses/3" \
  -H "Authorization: Bearer $TOKEN"
```

### Leave trip (non-owner)

```bash
curl -X POST "$BASE/api/trips/1/leave" \
  -H "Authorization: Bearer $TOKEN"
```

### Delete trip (owner only)

```bash
curl -X DELETE "$BASE/api/trips/1" \
  -H "Authorization: Bearer $TOKEN"
```

## Endpoint summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | No | Service health |
| POST | `/api/auth/register` | No | Register user, get API token |
| POST | `/api/trips` | Yes | Create trip |
| POST | `/api/trips/join` | Yes | Join trip by invite code |
| GET | `/api/trips` | Yes | List my trips |
| GET | `/api/trips/{id}` | Yes | Trip detail + balances |
| POST | `/api/trips/{id}/leave` | Yes | Leave trip |
| DELETE | `/api/trips/{id}` | Yes | Delete trip (owner) |
| GET | `/api/trips/{id}/expenses` | Yes | List expenses |
| POST | `/api/trips/{id}/expenses` | Yes | Add expense |
| DELETE | `/api/trips/{id}/expenses/{expenseId}` | Yes | Delete expense |

## Security notes

- Always use HTTPS in production.
- Treat `api_token` like a password; store it in the iOS Keychain.
- Restrict `CORS_ORIGINS` in production if you know your app origins.
- Keep `storage/` and `.env` outside the public web root (default layout does this).

## License

Part of the Inpenso / Expense Pro Tracker project.
