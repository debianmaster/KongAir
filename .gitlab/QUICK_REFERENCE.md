# GitLab CI/CD Quick Reference

## Pipeline Overview

```
┌─────────────┐    ┌─────────────────┐    ┌─────────────┐    ┌─────────────┐
│    Build    │───▶│   Kong Config   │───▶│    Stage    │───▶│   Deploy    │
│             │    │                 │    │             │    │             │
│ • Docker    │    │ • OAS→Kong      │    │ • PRD Branch│    │ • Production│
│ • Registry  │    │ • Validation    │    │ • Review    │    │ • Kong Sync │
└─────────────┘    └─────────────────┘    └─────────────┘    └─────────────┘
```

## Quick Commands

### Manual Deployment
```bash
# Deploy to staging (dry-run)
.gitlab/scripts/deploy.sh -e staging -t $KONNECT_PAT -d

# Deploy to production
.gitlab/scripts/deploy.sh -e production -t $KONNECT_PAT

# Check deployment script help
.gitlab/scripts/deploy.sh -h
```

### Kong Operations
```bash
# Validate Kong config
deck validate -s platform/kong/.generated/kong.yaml

# Check differences (dry-run)
deck diff --select-tag platform-repo-managed \
  -s platform/kong/.generated/kong.yaml \
  --konnect-runtime-group-name KongAir-PRD \
  --konnect-token $KONNECT_PAT
```

## Pipeline Stages

| Stage | Jobs | Purpose | Triggers |
|-------|------|---------|----------|
| **Build** | `build-docker` | Build & push Docker images | `main` branch, service changes |
| **Kong Config** | `check-kong-changes`<br>`convert-oas-to-kong`<br>`test-kong-config` | Generate Kong configs | Kong-related changes |
| **Stage** | `stage-kong-for-prd` | Stage for production | Generated Kong configs |
| **Deploy** | `deploy-kong-prd` | Deploy to production | `PRD/kong/kong.yaml` changes |

## Environment Variables

### Required
- `KONNECT_PAT` - Kong Konnect Personal Access Token

### Optional
- `KONNECT_RUNTIME_GROUP_STAGING` - Staging runtime group
- `KONNECT_RUNTIME_GROUP_PRODUCTION` - Production runtime group
- `CI_DEBUG_TRACE` - Enable debug output

## File Paths

| Purpose | Path |
|---------|------|
| Main Pipeline | `.gitlab-ci.yml` |
| Kong Artifacts | `.gitlab/artifacts/kong/` |
| Generated Config | `platform/kong/.generated/kong.yaml` |
| Production Config | `PRD/kong/kong.yaml` |
| Deployment Script | `.gitlab/scripts/deploy.sh` |

## Branch Strategy

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Primary development | Protected |
| `PRD/kong` | Production staging | Protected |
| `develop` | Feature development | Protected |
| `workflow/*` | CI/CD testing | Standard |

## Common Workflows

### 1. Service Update
```bash
# 1. Make changes to service
git checkout -b feature/service-update
# ... make changes ...

# 2. Push and create MR
git push origin feature/service-update
# Create merge request in GitLab

# 3. Pipeline automatically:
# - Builds Docker images
# - Generates Kong configs
# - Stages for production
```

### 2. Kong Configuration Update
```bash
# 1. Update Kong patches or configs
# ... make changes ...

# 2. Push to main
git push origin main

# 3. Pipeline automatically:
# - Detects Kong changes
# - Generates new configs
# - Stages for production review
```

### 3. Production Deployment
```bash
# 1. Review staged changes in PRD/kong branch
# 2. Merge to main (triggers deployment)
# 3. Pipeline automatically:
# - Deploys to production
# - Syncs Kong configuration
```

## Troubleshooting

### Pipeline Failures
1. **Check job logs** in GitLab CI/CD interface
2. **Verify environment variables** are set correctly
3. **Check runner availability** for required tags
4. **Validate Kong configurations** manually

### Common Issues
- **Docker builds fail**: Check registry access and runner Docker setup
- **Kong validation fails**: Verify OpenAPI specs and patch files
- **Deployment fails**: Check KONNECT_PAT and runtime group names
- **Branch operations fail**: Verify runner has write access

### Debug Mode
```bash
# Enable debug output
CI_DEBUG_TRACE=true

# Check pipeline variables
echo $CI_COMMIT_BRANCH
echo $CI_PROJECT_PATH
```

## Security Notes

- Production deployment requires `production` runner tag
- Sensitive variables are protected and masked
- Only `main` branch can trigger production deployment
- Kong tokens are stored as protected variables

## Performance Tips

- Use Docker layer caching for faster builds
- Parallel job execution where possible
- Optimize Kong configuration generation
- Monitor pipeline execution times

## Support

- **Documentation**: `.gitlab/README.md`
- **Migration Guide**: `.gitlab/MIGRATION_GUIDE.md`
- **GitLab CI/CD Docs**: https://docs.gitlab.com/ee/ci/
- **Kong Deck Docs**: https://docs.konghq.com/deck/
