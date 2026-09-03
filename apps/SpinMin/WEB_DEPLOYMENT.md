# Web Deployment Options

While SpinMin is primarily a **native iOS app** (SwiftUI), we've created a web-based tire pressure calculator that can be accessed from any browser.

## Current Web Calculator

The web calculator (`web-calculator/index.html`) includes:
- ✓ Tire pressure calculation (same algorithm as iOS app)
- ✓ Mobile-responsive design
- ✓ Real-time results
- ✓ Works on any device with a browser

**Does NOT include** (iOS app only):
- ✗ Bike configurations & storage
- ✗ Gear ratio analysis
- ✗ Maintenance tracking
- ✗ Ride scheduling
- ✗ iCloud sync
- ✗ Gear locker

## Quick Deployment Options

### Option 1: GitHub Pages (Recommended - Free & Easy)

1. **Push to GitHub** (already done):
   ```bash
   git push origin cursor/tire-pressure-calculator-spin-min-09fa
   ```

2. **Enable GitHub Pages**:
   - Go to your repo settings
   - Pages → Source → Deploy from branch
   - Branch: `cursor/tire-pressure-calculator-spin-min-09fa`
   - Folder: `/apps/SpinMin/web-calculator`
   - Save

3. **Access**:
   - URL: `https://[username].github.io/[repo]/apps/SpinMin/web-calculator/`
   - Works on any device instantly
   - Free forever
   - Automatic updates when you push changes

### Option 2: Netlify (Best Performance)

1. **Deploy via Netlify CLI**:
   ```bash
   cd apps/SpinMin/web-calculator
   npx netlify-cli deploy --dir . --prod
   ```

2. **Or via Netlify UI**:
   - Go to netlify.com
   - "Add new site" → "Import existing project"
   - Connect to GitHub
   - Base directory: `apps/SpinMin/web-calculator`
   - Build command: (leave empty)
   - Publish directory: `.`
   - Deploy!

3. **Access**:
   - Custom URL: `your-app.netlify.app`
   - Custom domain supported (free)
   - Automatic HTTPS
   - Global CDN
   - Preview deploys for branches

### Option 3: Vercel (Developer-Friendly)

1. **Deploy**:
   ```bash
   cd apps/SpinMin/web-calculator
   npx vercel --prod
   ```

2. **Access**:
   - URL: `your-app.vercel.app`
   - Custom domains
   - Automatic HTTPS
   - Edge network

### Option 4: Cloudflare Pages (Fastest)

1. **Deploy**:
   - Go to pages.cloudflare.com
   - "Create a project"
   - Connect GitHub repo
   - Build directory: `apps/SpinMin/web-calculator`
   - Deploy

2. **Access**:
   - URL: `your-app.pages.dev`
   - Fastest global delivery
   - Unlimited bandwidth
   - Free forever

## Recommended: Deploy to GitHub Pages Now

Since your code is already pushed, enabling GitHub Pages takes **30 seconds**:

1. Go to: `https://github.com/[your-username]/[your-repo]/settings/pages`
2. Source: "Deploy from a branch"
3. Branch: `cursor/tire-pressure-calculator-spin-min-09fa`
4. Folder: `/apps/SpinMin/web-calculator`
5. Click Save
6. Wait 1-2 minutes for build
7. Visit your URL!

## Access URL from Mobile

Once deployed, you can:
- Visit the URL on your phone's browser
- Add to home screen (works like an app!)
- Share with others
- No installation required

## Native iOS App Deployment

For the **full native iOS app** with all features, you'll need:

### TestFlight (Beta Testing)

1. **Requirements**:
   - Apple Developer Account ($99/year)
   - Xcode on Mac
   - Physical iPhone or TestFlight app

2. **Process**:
   ```bash
   # Open in Xcode
   open apps/SpinMin/SpinMin.xcodeproj
   
   # Archive for distribution
   Product → Archive
   
   # Upload to App Store Connect
   Distribute App → App Store Connect → Upload
   
   # TestFlight
   App Store Connect → TestFlight → Add testers
   ```

3. **Access**:
   - Install TestFlight app on iPhone
   - Accept invite via email
   - Install SpinMin from TestFlight
   - Test full app with all features

### App Store (Public Release)

1. **After TestFlight testing**:
   - Submit for App Review
   - Wait 1-2 days for approval
   - Release to App Store

2. **Users can**:
   - Download from App Store
   - Automatic updates
   - Full native experience

## Comparison

| Method | Time | Cost | Features | Platforms |
|--------|------|------|----------|-----------|
| **GitHub Pages** | 2 min | Free | Calculator only | Any browser |
| **Netlify** | 5 min | Free | Calculator only | Any browser |
| **TestFlight** | 1-2 hours | $99/year | All features | iOS only |
| **App Store** | 2-3 days | $99/year | All features | iOS only |

## Progressive Web App (Future)

We could expand the web calculator into a full PWA:

**Potential additions**:
- Add to home screen (app-like icon)
- Offline support (Service Worker)
- Local storage for bikes
- Responsive layouts
- Push notifications
- Basic gear calculator

**Still limited compared to native**:
- No iCloud sync
- No native UI polish
- Limited iOS integration
- No app store presence

## Recommended Path

**For quick mobile testing** (right now):
1. Deploy web calculator to GitHub Pages (2 minutes)
2. Open on your phone
3. Test tire pressure calculations
4. Add to home screen

**For full app experience** (when ready):
1. Open project in Xcode
2. Build for your iPhone
3. Install via Xcode
4. Test all native features
5. Deploy to TestFlight when happy
6. Submit to App Store for public release

## Local Testing (Within Cursor)

If you want to test locally within this environment:

```bash
# Start server (already running!)
cd apps/SpinMin/web-calculator
python3 -m http.server 8080

# Server running at:
# http://localhost:8080
```

But you can't access `localhost` from your phone unless:
- Phone is on same network
- You expose the port via ngrok or similar
- Better: just deploy to GitHub Pages!
