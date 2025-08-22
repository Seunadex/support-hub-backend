# Support Hub — Backend

A Rails 8 API backend for a customer support ticketing system.
Built with **Ruby on Rails 8**, **PostgreSQL**, **GraphQL**, **Devise JWT**, **Pundit**, **Active Storage**, and **Solid Queue**.

---

## Features

- User roles: **Agent** and **Customer**
- Ticket management
- File attachments via Active Storage & GraphQL uploads
- Authentication with Devise (jwt)
- Authorization with Pundit policies
- Background jobs with Solid Queue
- Daily email digest of open tickets for agents
- CSV export of tickets closed in the last 30 days

---

## 🚀 Local Setup

1. **Clone repo**
   ```bash
   git clone https://github.com/Seunadex/support-hub-backend.git
   cd support-hub-backend
   ```
2. **Set environment variables**

   Copy the example environment file and update values as needed:

   ```bash
   cp .env.example .env
   ```

   `.env.example` includes `DEVISE_JWT_SECRET_KEY`. You need to generate a secret using `bin/rails secret` and set it either in `.env` or in Rails credentials.

   Edit `.env` to set your environment variables.

3. **Run setup script**

   ```bash
   bin/setup
   ```

   ```bash
   bin/dev
   ```

### 🔑 JWT Secret Setup

The app uses Devise JWT. You must provide a secret key:

1. Generate one: `bin/rails secret`
2. Add to `.env`:
   DEVISE_JWT_SECRET_KEY=<secret>
   Or add to `config/credentials/development.yml.enc`:
   devise_jwt_secret_key: <secret>

## 🧪 Running Tests

Run the full test suite using RSpec:

```bash
bundle exec rspec
```
