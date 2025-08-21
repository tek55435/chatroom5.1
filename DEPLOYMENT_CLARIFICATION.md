# Deployment Clarification

## Current Live Deployment
- **Platform**: Google App Engine
- **Domain**: https://hear-all-v11-1.uc.r.appspot.com
- **Project ID**: hear-all-v11-1

## Deployment Method
We are using Google App Engine for our live deployments. This provides:
- Automatic scaling
- Managed infrastructure
- Built-in load balancing
- Easy domain management

## Files Used
- `server/app.yaml` - App Engine configuration for Node.js backend
- `deploy-to-appengine.ps1` - Automated deployment script
- `APP-ENGINE-DEPLOYMENT-GUIDE.md` - Complete deployment instructions

## Quick Deploy
To deploy updates to the live site:
```powershell
.\deploy-to-appengine.ps1
```

This will deploy both the backend server and Flutter web frontend to App Engine.