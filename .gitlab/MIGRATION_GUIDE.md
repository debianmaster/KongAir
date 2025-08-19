# Migration Guide: GitHub Actions to GitLab CI/CD

This guide helps you migrate from the existing GitHub Actions workflows to GitLab CI/CD for the KongAir project.

## Overview

The migration involves converting GitHub Actions workflows to GitLab CI/CD pipelines while maintaining the same functionality:
- Docker image building and publishing
- Kong Gateway configuration generation
- Staging and production deployment
- Automated testing and validation

## Prerequisites

Before starting the migration, ensure you have:

1. **GitLab Account**: Access to a GitLab instance (GitLab.com or self-hosted)
2. **Project Access**: Admin access to the KongAir project in GitLab
3. **Kong Konnect Access**: Valid Personal Access Token for Kong Konnect
4. **GitLab Runners**: Access to runners with `docker` and `production` tags

## Migration Steps

### 1. Project Setup

#### Create GitLab Project
1. Create a new project in GitLab
2. Import your existing KongAir repository
3. Ensure all branches and history are preserved

#### Configure Project Settings
1. Go to **Settings > General**
2. Set project visibility (private recommended for production code)
3. Configure merge request settings
4. Set up protected branches (`main`, `PRD/kong`, `develop`)

### 2. CI/CD Variables Configuration

#### Required Variables
Navigate to **Settings > CI/CD > Variables** and add:

| Variable | Type | Protected | Masked | Description |
|----------|------|-----------|---------|-------------|
| `KONNECT_PAT` | Variable | ✅ | ✅ | Kong Konnect Personal Access Token |
| `DOCKER_REGISTRY_USERNAME` | Variable | ✅ | ❌ | GitLab Container Registry username |
| `DOCKER_REGISTRY_PASSWORD` | Variable | ✅ | ✅ | GitLab Container Registry password |

#### Optional Variables
| Variable | Type | Protected | Masked | Description |
|----------|------|-----------|---------|-------------|
| `KONNECT_RUNTIME_GROUP_STAGING` | Variable | ❌ | ❌ | Staging runtime group name |
| `KONNECT_RUNTIME_GROUP_PRODUCTION` | Variable | ✅ | ❌ | Production runtime group name |
| `CI_DEBUG_TRACE` | Variable | ❌ | ❌ | Enable debug output (`true`/`false`) |

### 3. Runner Configuration

#### Docker Runners
Ensure you have runners with the `docker` tag for:
- Building Docker images
- Processing Kong configurations
- Running tests

#### Production Runners
Ensure you have runners with the `production` tag for:
- Production deployments
- Sensitive operations

#### Runner Requirements
- **Docker**: For container operations
- **Git**: For repository operations
- **Kong Deck**: For Kong Gateway operations

### 4. Container Registry Setup

#### Enable Container Registry
1. Go to **Packages & Registries > Container Registry**
2. Ensure registry is enabled for your project
3. Note the registry URL: `registry.gitlab.com/[group]/[project]`

#### Registry Authentication
The pipeline automatically authenticates using GitLab's built-in authentication.

## Configuration Differences

### 1. File Structure

| GitHub Actions | GitLab CI/CD |
|----------------|--------------|
| `.github/workflows/` | `.gitlab-ci.yml` |
| `.github/artifacts/` | `.gitlab/artifacts/` |
| `actions/checkout@v3` | Built-in checkout |
| `actions/upload-artifact@v3` | Built-in artifacts |

### 2. Syntax Differences

#### Triggers
```yaml
# GitHub Actions
on:
  push:
    branches: [main]
    paths-ignore: ['PRD/**']

# GitLab CI/CD
rules:
  - if: $CI_COMMIT_BRANCH == "main"
    changes:
      - "!PRD/**"
```

#### Job Dependencies
```yaml
# GitHub Actions
needs: [job-name]

# GitLab CI/CD
needs:
  - job-name
```

#### Environment Variables
```yaml
# GitHub Actions
${{ secrets.KONNECT_PAT }}

# GitLab CI/CD
$KONNECT_PAT
```

### 3. Docker Operations

#### GitHub Actions
```yaml
- uses: docker/setup-buildx-action@v2
- uses: docker/login-action@v2
- uses: docker/build-push-action@v4
```

#### GitLab CI/CD
```yaml
services:
  - docker:24.0.5-dind
variables:
  DOCKER_HOST: tcp://docker:2376
  DOCKER_TLS_VERIFY: 1
```

## Testing the Migration

### 1. Initial Pipeline Run
1. Push the `.gitlab-ci.yml` file to your repository
2. Monitor the pipeline execution in GitLab
3. Check for any configuration errors

### 2. Validate Each Stage
- **Build Stage**: Verify Docker images are built and pushed
- **Kong Config Stage**: Check Kong configuration generation
- **Stage Stage**: Verify staging branch creation
- **Deploy Stage**: Test production deployment (with dry-run)

### 3. Test Kong Operations
```bash
# Test Kong configuration validation
deck validate -s platform/kong/.generated/kong.yaml

# Test dry-run deployment
deck diff --select-tag platform-repo-managed \
  -s platform/kong/.generated/kong.yaml \
  --konnect-runtime-group-name KongAir-Staging \
  --konnect-token $KONNECT_PAT
```

## Troubleshooting

### Common Issues

#### 1. Docker Build Failures
**Problem**: Docker builds fail with authentication errors
**Solution**: 
- Verify GitLab Container Registry is enabled
- Check runner has access to Docker daemon
- Ensure proper Docker-in-Docker service configuration

#### 2. Kong Configuration Errors
**Problem**: Kong Deck operations fail
**Solution**:
- Verify Kong Deck version compatibility
- Check OpenAPI specification syntax
- Validate Kong patch files

#### 3. Deployment Failures
**Problem**: Production deployment fails
**Solution**:
- Verify `KONNECT_PAT` is set and valid
- Check runner has `production` tag
- Validate runtime group configuration

#### 4. Branch Management Issues
**Problem**: PRD branch creation/update fails
**Solution**:
- Ensure runner has write access to repository
- Check protected branch settings
- Verify Git configuration in pipeline

### Debug Mode
Enable debug output by setting `CI_DEBUG_TRACE: "true"` in GitLab CI/CD variables.

### Log Analysis
- Check job logs for detailed error messages
- Use GitLab's built-in log viewer
- Compare with successful GitHub Actions runs

## Post-Migration Tasks

### 1. Update Documentation
- Update README files to reference GitLab
- Modify deployment instructions
- Update team workflows

### 2. Team Training
- Train team on GitLab CI/CD interface
- Explain pipeline stages and triggers
- Demonstrate troubleshooting procedures

### 3. Monitor and Optimize
- Monitor pipeline performance
- Optimize job execution times
- Adjust resource allocation as needed

### 4. Cleanup
- Remove GitHub Actions workflows (after confirming GitLab works)
- Archive GitHub-specific documentation
- Update CI/CD references in code

## Rollback Plan

If issues arise during migration:

1. **Immediate Rollback**: Revert `.gitlab-ci.yml` changes
2. **Restore GitHub Actions**: Re-enable GitHub Actions workflows
3. **Investigate Issues**: Debug GitLab-specific problems
4. **Re-attempt Migration**: Fix issues and try again

## Support Resources

### GitLab Documentation
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [GitLab Container Registry](https://docs.gitlab.com/ee/user/packages/container_registry/)
- [GitLab Runners](https://docs.gitlab.com/runner/)

### Kong Documentation
- [Kong Deck CLI](https://docs.konghq.com/deck/)
- [Kong Konnect](https://docs.konghq.com/konnect/)

### Community Support
- GitLab Community Forum
- Kong Community Slack
- Stack Overflow (tagged with gitlab-ci, kong)

## Conclusion

This migration guide provides a comprehensive path from GitHub Actions to GitLab CI/CD. The key is to:

1. **Plan thoroughly** before starting
2. **Test incrementally** at each stage
3. **Validate functionality** matches the original
4. **Train the team** on new processes
5. **Monitor closely** after migration

With proper preparation and testing, the migration should provide the same functionality with GitLab's integrated CI/CD platform.
