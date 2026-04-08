# Acuis Backend

Backend proxy server for the Acuis app. Securely handles NVIDIA API calls without exposing the API key in the client app.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file:
```bash
cp .env.example .env
```

3. Add your NVIDIA API key to `.env`:
```
NVIDIA_API_KEY=your_actual_key_here
PORT=3000
```

4. Run the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm run dev
```

## API Endpoints

- `GET /health` - Health check endpoint
- `POST /api/chat/completions` - Proxy for NVIDIA chat completions

## Security Features

- Rate limiting (100 requests per 15 minutes per IP)
- CORS enabled
- Helmet security headers
- Request validation
- API key never exposed to client

## Deployment

You can deploy this to:
- **Vercel** (easiest): `vercel deploy`
- **Railway**: Connect GitHub repo
- **Render**: Connect GitHub repo
- **Heroku**: `git push heroku main`
- **Your own VPS**: Use PM2 or systemd

Make sure to set the `NVIDIA_API_KEY` environment variable in your deployment platform.
