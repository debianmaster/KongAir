# GitLab CI/CD Pipeline for KongAir

This directory contains the GitLab CI/CD pipeline configuration that mirrors the existing GitHub Actions workflows.

## Overview

The pipeline consists of four main stages:

1. **Build** - Builds and pushes Docker images for all services
2. **Kong Config** - Converts OpenAPI specs to Kong configurations and validates them
3. **Stage** - Stages Kong changes for production deployment
4. **Deploy** - Deploys Kong configurations to production

## Pipeline Stages

### 1. Build Stage (`build-docker`)

- **Purpose**: Builds and pushes Docker images for all KongAir services
- **Services**: flights, routes, bookings, customer, experience
- **Triggers**: Changes to flight-data/, sales/, or experience/ directories on main branch
- **Output**: Docker images pushed to GitLab Container Registry

**Configuration**:
- Uses Docker-in-Docker (DinD) for building images
- Supports multi-platform builds (linux/amd64, linux/arm64)
- Tags images with both `latest` and commit SHA
- Pushes to `registry.gitlab.com/[project-path]/kongair-[service-name]`

### 2. Kong Configuration Stage

#### `check-kong-changes`
- **Purpose**: Determines if Kong-related files have changed
- **Triggers**: Changes to Kong configurations, OpenAPI specs, or platform files
- **Output**: Sets environment variable `has_changes` for downstream jobs

#### `convert-oas-to-kong`
- **Purpose**: Converts OpenAPI specifications to Kong Gateway configurations
- **Dependencies**: Requires `check-kong-changes` job
- **Tools**: Uses Kong Deck CLI (v1.26.0)
- **Output**: Generated Kong configurations in `.gitlab/artifacts/kong/`

**Process**:
1. Converts each service's OpenAPI spec to Kong config
2. Applies patches from `kong/patches.yaml` files
3. Adds appropriate tags for service identification
4. Merges all configurations into a combined file
5. Applies platform-level configurations and patches

#### `test-kong-config`
- **Purpose**: Validates and tests Kong configurations
- **Dependencies**: Requires `convert-oas-to-kong` job
- **Activities**: 
  - Validates configuration syntax
  - Performs dry-run diff against production

### 3. Staging Stage (`stage-kong-for-prd`)

- **Purpose**: Stages Kong configurations for production deployment
- **Dependencies**: Requires `convert-oas-to-kong` job
- **Process**:
  1. Copies generated Kong config to `PRD/kong/kong.yaml`
  2. Creates or updates `PRD/kong` branch
  3. Commits and pushes changes for review

### 4. Deployment Stage (`deploy-kong-prd`)

- **Purpose**: Deploys Kong configurations to production
- **Triggers**: Changes to `PRD/kong/kong.yaml` on main branch
- **Environment**: Production environment with Kong Konnect
- **Process**: Uses Kong Deck to sync configuration to production

## Configuration

### Environment Variables

The following environment variables need to be configured in GitLab:

- `KONNECT_PAT`: Kong Konnect Personal Access Token for production deployment

### GitLab Runners

The pipeline requires runners with the following tags:
- `docker`: For Docker builds and Kong configuration processing
- `production`: For production deployment (restricted access)

### Registry Configuration

Docker images are pushed to GitLab Container Registry:
- Registry: `registry.gitlab.com`
- Project path: `[group]/[project]`
- Image prefix: `kongair-[service-name]`

## File Structure

```
.gitlab/
├── README.md                 # This file
├── artifacts/                # Pipeline artifacts
│   └── kong/                # Kong configuration artifacts
└── .gitlab-ci.yml           # Main pipeline configuration (in root)
```

## Differences from GitHub Actions

### 1. Branch Management
- **GitHub**: Uses `peter-evans/create-pull-request` action
- **GitLab**: Manually creates/updates `PRD/kong` branch

### 2. Artifacts
- **GitHub**: Uses `actions/upload-artifact` action
- **GitLab**: Uses built-in GitLab artifacts system

### 3. Docker Registry
- **GitHub**: Uses GitHub Container Registry (ghcr.io)
- **GitLab**: Uses GitLab Container Registry

### 4. Change Detection
- **GitHub**: Uses `dorny/paths-filter` action
- **GitLab**: Uses Git diff commands with custom logic

## Troubleshooting

### Common Issues

1. **Docker Build Failures**
   - Check if Docker-in-Docker service is running
   - Verify registry authentication
   - Check Dockerfile syntax in service directories

2. **Kong Configuration Errors**
   - Validate OpenAPI specifications
   - Check Kong patch files for syntax errors
   - Verify Kong Deck version compatibility

3. **Deployment Failures**
   - Verify `KONNECT_PAT` environment variable
   - Check Kong Konnect runtime group configuration
   - Validate production environment access

### Debug Mode

To enable debug output, add `CI_DEBUG_TRACE: "true"` to your GitLab CI/CD variables.

## Security Considerations

1. **Production Access**: Only runners with `production` tag can deploy to production
2. **Secrets**: Kong Konnect tokens are stored as protected variables
3. **Branch Protection**: Production deployment only occurs from main branch
4. **Artifact Expiration**: Kong configurations expire after 1 week

## Maintenance

### Updating Kong Deck Version
Update the image version in the following jobs:
- `convert-oas-to-kong`
- `stage-kong-for-prd`
- `deploy-kong-prd`
- `test-kong-config`

### Adding New Services
1. Add service to the `SERVICES` array in `build-docker` job
2. Add OpenAPI spec conversion in `convert-oas-to-kong` job
3. Update change detection patterns in `check-kong-changes` job

### Modifying Deployment Process
1. Update `deploy-kong-prd` job configuration
2. Modify environment settings
3. Update deployment scripts as needed
