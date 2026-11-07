# DynamicGold ERP & Multi-Tenant Platform

ProGold is an enterprise-grade ERP and gold management system built with Flutter (Frontend) and Node.js / Express with PostgreSQL (Backend).

## Architecture

- **`frontend/`**: Flutter Web & Mobile Application featuring responsive UI, POS & billing, tenant management, catalogue, and scheme management.
- **`backend/`**: Node.js & Express REST API backed by PostgreSQL, JWT authentication, and automated email services. Tenant records and OTPs live in `public`; each tenant receives a separate PostgreSQL schema.

## Getting Started

### Prerequisites
- Node.js (v18+)
- Flutter SDK (v3.0+)
- A PostgreSQL database (Aiven is the configured target)

### Backend Setup
1. Navigate to backend:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Copy environment variables:
   ```bash
   cp .env.example .env
   ```
   Set `DATABASE_URL` to the PostgreSQL connection URI from your provider, and configure the SMTP and ImageKit values as needed. Keep this secret in the backend environment only; do not put it in the Flutter app or commit it.
4. Run server:
   ```bash
   npm start
   ```

The database user must be allowed to create schemas and tables. The backend initializes the shared master tables on startup and creates a tenant schema during account registration. This setup starts with an empty PostgreSQL database; it does not migrate existing Turso tenant data.

### Frontend Setup
1. Navigate to frontend:
   ```bash
   cd frontend
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run app:
   ```bash
   flutter run -d chrome
   ```
