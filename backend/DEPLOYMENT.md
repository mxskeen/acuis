# Backend Deployment Guide

## Quick Deploy Options

### Option 1: Vercel (Recommended - Easiest)

1. Install Vercel CLI:
```bash
npm i -g vercel
```

2. Deploy from the backend directory:
```bash
cd backend
vercel
```

3. Add your NVIDIA API key as an environment variable:
```bash
vercel env add NVIDIA_API_KEY
```
Paste your key when prompted, select "Production", "Preview", and "Development".

4. Redeploy to apply the environment variable:
```bash
vercel --prod
```

5. Copy your deployment URL (e.g., `https://your-app.vercel.app`)

6. Add `BACKEND_URL` secret to GitHub:
   - Go to your GitHub repo → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `BACKEND_URL`
   - Value: `https://your-app.vercel.app` (your Vercel URL)

### Option 2: Railway

1. Go to [railway.app](https://railway.app)
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repository
4. Set root directory to `/backend`
5. Add environment variable:
   - Key: `NVIDIA_API_KEY`
   - Value: Your NVIDIA API key
6. Deploy
7. Copy the generated URL and add it as `BACKEND_URL` secret in GitHub

### Option 3: Render

1. Go to [render.com](https://render.com)
2. Click "New +" → "Web Service"
3. Connect your GitHub repository
4. Configure:
   - Root Directory: `backend`
   - Build Command: `npm install`
   - Start Command: `npm start`
5. Add environment variable:
   - Key: `NVIDIA_API_KEY`
   - Value: Your NVIDIA API key
6. Deploy
7. Copy the URL and add it as `BACKEND_URL` secret in GitHub

### Option 4: Your Own VPS

1. SSH into your server
2. Clone the repository
3. Install Node.js (v18+)
4. Setup:
```bash
cd backend
npm install
cp .env.example .env
nano .env  # Add your NVIDIA_API_KEY
```

5. Install PM2 for process management:
```bash
npm install -g pm2
pm2 start server.js --name acuis-backend
pm2 save
pm2 startup
```

6. Setup nginx reverse proxy (optional but recommended):
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

7. Add your domain/IP as `BACKEND_URL` secret in GitHub

## After Deployment

1. Test your backend:
```bash
curl https://your-backend-url/health
```

Should return: `{"status":"ok","timestamp":"..."}`

2. Update GitHub Secrets:
   - Go to your repo → Settings → Secrets and variables → Actions
   - Add or update `BACKEND_URL` with your deployed backend URL
   - You can now remove the `NVIDIA_API_KEY` secret from GitHub (it's only needed in the backend)

3. Push to main branch to trigger a new build with the backend URL

## Local Development

For local development, you can run the backend locally:

```bash
cd backend
npm install
cp .env.example .env
# Edit .env and add your NVIDIA_API_KEY
npm run dev
```

Then build the Flutter app with:
```bash
cd acuis
flutter build apk --release --dart-define=BACKEND_URL="http://localhost:3000"
```

## Security Notes

- The NVIDIA API key is now only stored on your backend server
- Never commit `.env` files to git
- Use HTTPS in production (all recommended platforms provide this automatically)
- The backend includes rate limiting (100 requests per 15 minutes per IP)
- Consider adding authentication if you want to restrict access to your backend
