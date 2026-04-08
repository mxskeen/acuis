# Security Improvement: Backend Proxy Architecture

## What Changed

Previously, the NVIDIA API key was compiled directly into the app binaries (APK/AAB), making it vulnerable to extraction through decompilation. Now, the API key is securely stored on a backend server that acts as a proxy.

## Architecture

```
Flutter App → Backend Server → NVIDIA API
             (holds API key)
```

### Before:
- API key compiled into app with `--dart-define=NVIDIA_API_KEY`
- Anyone could decompile the app and extract the key
- Key exposed in all distributed binaries

### After:
- API key stored only on backend server
- App calls backend, backend calls NVIDIA API
- Key never leaves the server
- App binaries contain only the backend URL

## Files Created

### Backend Server (`/backend`)
- `server.js` - Express server that proxies NVIDIA API calls
- `package.json` - Node.js dependencies
- `.env.example` - Environment variable template
- `.gitignore` - Prevents committing secrets
- `README.md` - Backend documentation
- `DEPLOYMENT.md` - Deployment instructions
- `vercel.json` - Vercel deployment config

## Files Modified

### Flutter App
- `lib/models/ai_config.dart` - Updated to use backend URL instead of direct NVIDIA API
- `lib/shared/services/ai_task_generator_service.dart` - Conditional auth headers
- `lib/shared/services/smart_todo_generator_service.dart` - Conditional auth headers
- `lib/shared/services/journey_planner_service.dart` - Conditional auth headers
- `lib/shared/services/scoring/alignment_scorer.dart` - Conditional auth headers
- `lib/features/today/today_view.dart` - Uses AIConfig for URL and model
- `lib/features/alignment/widgets/interactive_details.dart` - Conditional auth headers (4 API calls)

### CI/CD
- `.github/workflows/release.yml` - Changed from `NVIDIA_API_KEY` to `BACKEND_URL`

## How It Works

1. **Backend Server**: Holds the NVIDIA API key securely
2. **Flutter App**: Sends requests to backend (no API key needed)
3. **Backend Proxy**: Forwards requests to NVIDIA API with the key
4. **Response**: Backend returns NVIDIA's response to the app

## Deployment Steps

1. Deploy the backend server (see `backend/DEPLOYMENT.md`)
2. Add `BACKEND_URL` secret to GitHub Actions
3. Remove `NVIDIA_API_KEY` from GitHub Actions (no longer needed)
4. Push to trigger new builds with backend URL

## Security Benefits

✅ API key never exposed in client app
✅ Rate limiting on backend (100 req/15min per IP)
✅ Single point of key management
✅ Can rotate keys without rebuilding app
✅ Can add authentication/authorization later
✅ Monitoring and logging on backend

## Backward Compatibility

Users can still use custom API providers by configuring their own API key in the app settings. The conditional auth header logic checks if the key is "backend-proxy" and skips the Authorization header in that case.

## Next Steps

1. Deploy backend to Vercel/Railway/Render (easiest options)
2. Update GitHub secret `BACKEND_URL` with your deployed URL
3. Remove `NVIDIA_API_KEY` from GitHub secrets
4. Push to main to trigger new builds
5. Test the app to ensure AI features work correctly

## Local Development

For local testing:
```bash
# Terminal 1 - Run backend
cd backend
npm install
cp .env.example .env
# Edit .env and add NVIDIA_API_KEY
npm run dev

# Terminal 2 - Build app
cd acuis
flutter build apk --dart-define=BACKEND_URL="http://localhost:3000"
```
