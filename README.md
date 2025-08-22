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
2. **Run setup script**

    ```bash
    bin/setup
    ```
    ```bash
    bin/dev
    ```

## 🧪 Running Tests

Run the full test suite using RSpec:

```bash
bundle exec rspec
```