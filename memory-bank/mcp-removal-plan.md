# MCP SERVER REMOVAL PLAN

## 📋 EXECUTIVE SUMMARY

This document outlines the comprehensive plan to remove the Model Context Protocol (MCP) server implementation from the k8s-n8n-nabi project. The removal will simplify the project to focus solely on n8n workflow automation without MCP integration.

## 🔍 ANALYSIS RESULTS

### MCP Components Identified ✅

#### 1. **Complete MCP Server Implementation**

- **Directory**: `mcp-server/` (entire directory)
  - Source code: `src/server.ts` (16KB, 516 lines)
  - Dependencies: `package.json`, `package-lock.json`
  - Build configuration: `tsconfig.json`, `Dockerfile`
  - Documentation: `README.md`
  - Tools directory: `src/tools/`

#### 2. **Container & Orchestration Configurations**

- **Docker Compose**: `docker-compose.yml` - MCP server service definition
- **Kubernetes**: `k8s/base/mcp-server.yaml` - Complete K8s deployment manifest
- **Deployment Script**: `rebuild-and-deploy.sh` - MCP-specific build and deploy logic

#### 3. **Dependencies & Testing**

- **Root Dependencies**: `package.json` - `fastmcp`, `mcp-proxy`
- **Test Files**: `test-mcp-server.js`, `test-sse-client.js`
- **Package Lock**: `package-lock.json` - MCP dependency entries

#### 4. **Documentation & Context**

- **Main README**: Extensive MCP integration documentation
- **Troubleshooting Guide**: `docs/troubleshooting.md` - MCP-specific issues
- **Memory Bank**: References in all context files

## 🎯 REMOVAL STRATEGY

### Phase 1: Infrastructure Removal (High Priority)

1. **Container Services** - Remove MCP server from Docker Compose
2. **Kubernetes Resources** - Delete MCP server deployment manifest
3. **Deployment Scripts** - Remove MCP build and deploy logic

### Phase 2: Source Code Removal (High Priority)

1. **MCP Server Directory** - Complete removal of `mcp-server/`
2. **Test Files** - Remove MCP-specific test implementations
3. **Dependencies** - Clean up package.json and package-lock.json

### Phase 3: Documentation Updates (Medium Priority)

1. **Project Documentation** - Update README and docs to remove MCP references
2. **Memory Bank Updates** - Update all context files to reflect MCP removal
3. **Project Description** - Update project purpose and scope

### Phase 4: Verification & Testing (High Priority)

1. **Build Verification** - Ensure project builds without MCP components
2. **Deployment Testing** - Verify Docker Compose and K8s deployments work
3. **Functionality Testing** - Confirm n8n operates independently

## 📝 DETAILED REMOVAL PLAN

### Step 1: Container Configuration Updates

#### Docker Compose Changes (`docker-compose.yml`)

**REMOVE:**

```yaml
mcp-server:
  build:
    context: ./mcp-server
  ports:
    - "1991:1991"
    - "1992:1992"
  environment:
    - MCP_SERVER_PORT=1991
    - MCP_SERVER_LOG_LEVEL=debug
    - N8N_BASE_URL=http://n8n:5678/api/v1
    - N8N_API_KEY=...
    - NODE_ENV=production
    - MCP_TRANSPORT_TYPE=sse
    - MCP_SSE_ENABLED=true
  depends_on:
    - n8n
  networks:
    - mcp-n8n-network
  restart: always
```

**UPDATE NETWORK NAME:**

- Change `mcp-n8n-network` to `n8n-network` throughout file

#### Kubernetes Manifest Removal

**DELETE FILE:** `k8s/base/mcp-server.yaml`

#### Deployment Script Updates (`rebuild-and-deploy.sh`)

**REMOVE SECTIONS:**

- MCP server build logic (lines referencing mcp-server)
- MCP Docker image removal commands
- MCP server logging commands

### Step 2: Source Code & Dependencies Removal

#### Complete Directory Removal

**DELETE:** `mcp-server/` (entire directory with all contents)

#### Root Package.json Updates (`package.json`)

**REMOVE DEPENDENCIES:**

```json
"fastmcp": "^1.20.5"
```

**UPDATE PROJECT METADATA:**

```json
{
  "name": "n8n-automation",
  "description": "n8n workflow automation platform",
  "main": "index.js",
  "scripts": {
    "test": "echo 'No tests specified'"
  }
}
```

#### Package Lock File

**REGENERATE:** `package-lock.json` after dependency removal

#### Test Files Removal

**DELETE FILES:**

- `test-mcp-server.js`
- `test-sse-client.js` (if purely MCP-related)

### Step 3: Documentation Updates

#### Main README Updates (`README.md`)

**REMOVE SECTIONS:**

- All MCP integration documentation
- MCP server setup instructions
- MCP testing procedures
- MCP tool descriptions

**UPDATE PROJECT TITLE:**

- From: "n8n-nabi: n8n with MCP Integration on AWS EKS"
- To: "n8n-automation: n8n Workflow Platform on AWS EKS"

#### Troubleshooting Guide (`docs/troubleshooting.md`)

**REMOVE SECTIONS:**

- "n8n Cannot Connect to MCP Server"
- "MCP Server Issues"
- "MCP Server Pod Not Starting"

#### Memory Bank Updates

**UPDATE FILES:**

- `memory-bank/projectbrief.md` - Remove MCP references
- `memory-bank/productContext.md` - Remove MCP integration points
- `memory-bank/systemPatterns.md` - Remove MCP architectural patterns
- `memory-bank/techContext.md` - Remove MCP dependencies and testing
- `memory-bank/activeContext.md` - Update current focus
- `memory-bank/progress.md` - Update capabilities

### Step 4: Environment Variables & Configuration

#### N8N Configuration Updates

**REVIEW:** Any n8n environment variables that reference MCP
**REMOVE:** MCP-specific n8n configuration if present

#### Network Configuration

**UPDATE:** Network names from `mcp-n8n-network` to `n8n-network`

## ⚡ IMPLEMENTATION SEQUENCE

### Pre-Implementation Checklist

- [ ] Backup current project state
- [ ] Document current MCP functionality (if needed for reference)
- [ ] Verify no external dependencies on MCP server
- [ ] Plan downtime for testing (if in production)

### Implementation Order (Critical Path)

1. **Infrastructure First** - Remove container and K8s configs
2. **Dependencies** - Clean up package.json files
3. **Source Code** - Remove MCP server directory
4. **Testing** - Remove test files
5. **Documentation** - Update all documentation
6. **Verification** - Test complete system

### Post-Implementation Verification

- [ ] Docker Compose build and start successfully
- [ ] N8N accessible and functional
- [ ] No orphaned containers or images
- [ ] No broken references in documentation
- [ ] Project description accurately reflects scope

## 🚨 RISK ASSESSMENT

### Low Risk Items ✅

- **MCP Server Removal**: Self-contained implementation
- **Container Configuration**: Well-isolated service
- **Documentation Updates**: Non-functional changes

### Medium Risk Items ⚠️

- **Package Dependencies**: Ensure no hidden dependencies
- **Network Configuration**: Verify n8n still functions
- **Build Process**: Ensure build scripts work without MCP

### Mitigation Strategies

1. **Incremental Testing**: Test after each major removal step
2. **Backup Strategy**: Maintain project backup before changes
3. **Rollback Plan**: Document steps to restore MCP if needed

## 📊 IMPACT ANALYSIS

### Positive Impacts ✅

- **Simplified Architecture**: Removes unnecessary complexity
- **Reduced Dependencies**: Fewer external packages to maintain
- **Cleaner Deployment**: Simplified container orchestration
- **Focused Project Scope**: Clear n8n automation focus

### Areas Requiring Attention ⚠️

- **Project Description**: Update to reflect new scope
- **Documentation**: Comprehensive updates needed
- **Testing**: Verify n8n functions independently

## 🎯 SUCCESS METRICS

### Technical Success Criteria

- [ ] Project builds without errors
- [ ] Docker Compose starts all services successfully
- [ ] N8N interface accessible and functional
- [ ] No MCP references in final codebase
- [ ] Documentation accurately reflects project state

### Functional Success Criteria

- [ ] N8N workflows can be created and executed
- [ ] Database connectivity maintained
- [ ] No degradation in n8n performance
- [ ] Clean project structure maintained

## 📅 ESTIMATED TIMELINE

### Phase 1: Infrastructure (30 minutes)

- Docker Compose updates: 10 minutes
- Kubernetes manifest removal: 5 minutes
- Deployment script updates: 15 minutes

### Phase 2: Source Code (15 minutes)

- Directory removal: 5 minutes
- Package.json updates: 5 minutes
- Test file removal: 5 minutes

### Phase 3: Documentation (45 minutes)

- README updates: 20 minutes
- Memory Bank updates: 20 minutes
- Troubleshooting guide updates: 5 minutes

### Phase 4: Verification (30 minutes)

- Build testing: 15 minutes
- Deployment testing: 10 minutes
- Functional verification: 5 minutes

**Total Estimated Time: ~2 hours**

## 📋 COMPLETION CHECKLIST

### Infrastructure ✅

- [ ] MCP server removed from docker-compose.yml
- [ ] Network names updated throughout compose file
- [ ] mcp-server.yaml deleted from k8s/base/
- [ ] rebuild-and-deploy.sh updated to remove MCP references

### Source Code ✅

- [ ] mcp-server/ directory completely removed
- [ ] fastmcp dependency removed from package.json
- [ ] package-lock.json regenerated
- [ ] test-mcp-server.js deleted
- [ ] test-sse-client.js deleted (if MCP-only)

### Documentation ✅

- [ ] README.md updated to remove all MCP references
- [ ] Project title and description updated
- [ ] docs/troubleshooting.md MCP sections removed
- [ ] All memory-bank/ files updated
- [ ] Project scope clearly defined without MCP

### Verification ✅

- [ ] docker-compose up succeeds
- [ ] n8n accessible at expected URL
- [ ] PostgreSQL and Redis services functional
- [ ] No error messages related to missing MCP components
- [ ] Build process completes without MCP-related errors

## 📅 LAST UPDATED

**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Context**: MCP Server removal plan created - Ready for implementation
**Status**: ✅ ANALYSIS COMPLETE - PLAN READY FOR IMPLEMENTATION
