# MCP Server for n8n Integration

This directory contains the source code for the Model Context Protocol (MCP) server that integrates with n8n.

## Overview

The MCP server provides a standardized interface for AI agents to interact with various tools. The n8n workflow automation platform can connect to this MCP server using the [n8n-nodes-mcp](https://github.com/mep-org/n8n-nodes-mcp) community node.

## Tools Included

The MCP server comes with the following tools:

- **HTTP Request Tool**: Makes HTTP requests to external APIs
- Add more tools by creating JavaScript files in the `tools/` directory

## Setup Instructions

### Local Development

1. Install dependencies:

   ```bash
   cd mcp-server
   npm install
   ```

2. Run the server:
   ```bash
   npm start
   ```

### Building the Docker Image

```bash
docker build -t your-registry/mcp-server:latest .
```

### Pushing to Docker Registry

```bash
docker push your-registry/mcp-server:latest
```

## Integration with n8n

The MCP server is designed to work with n8n via the n8n-nodes-mcp community node. The n8n deployment automatically installs this node and connects to the MCP server.

## Adding New Tools

To add a new tool:

1. Create a new JavaScript file in the `tools/` directory
2. Define the tool using the MCP protocol format (see `tools/http-request.js` for an example)
3. Export the tool using `module.exports = { tool }`

## Environment Variables

The MCP server supports the following environment variables:

- `MCP_SERVER_PORT`: Port to run the server on (default: 3000)
- `MCP_SERVER_LOG_LEVEL`: Logging level (default: info)
