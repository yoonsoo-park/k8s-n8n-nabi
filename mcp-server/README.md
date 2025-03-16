# MCP Server for n8n Integration

This directory contains the source code for the Model Context Protocol (MCP) server that integrates with n8n. It uses FastMCP and TypeScript.

## Overview

The MCP server provides a standardized interface for AI agents to interact with various tools. The n8n workflow automation platform can connect to this MCP server using the [n8n-nodes-mcp](https://github.com/mep-org/n8n-nodes-mcp) community node.

## Tools Included

The MCP server comes with the following tools:

- **HTTP Request Tool**: Makes HTTP requests to external APIs
- **n8n List Workflows Tool**: Lists all workflows from the n8n instance
- Add more tools by creating TypeScript files in the `src/tools/` directory

## Setup Instructions

### Local Development

1. Install dependencies:

   ```bash
   cd mcp-server
   npm install
   ```

2. Build the TypeScript code:

   ```bash
   npm run build
   ```

3. Run the server:
   ```bash
   npm start
   ```

### Development with FastMCP CLI

You can use the FastMCP CLI for development and testing:

```bash
npm run dev
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

1. Create a new TypeScript file in the `src/tools/` directory
2. Define the tool using the FastMCP format with Zod for parameter validation
3. Export the tool as the default export

Example:

```typescript
import { z } from "zod";

const myTool = {
  name: "my_tool",
  description: "Description of my tool",
  parameters: z.object({
    param1: z.string().describe("Description of parameter 1"),
    param2: z.number().optional().describe("Description of parameter 2"),
  }),
  execute: async (params) => {
    // Tool implementation
    return JSON.stringify({
      result: "Success",
      // More result data
    });
  },
};

export default myTool;
```

## Environment Variables

The MCP server supports the following environment variables:

- `MCP_SERVER_PORT`: Port to run the server on (default: 1991)
- `MCP_TRANSPORT_TYPE`: Transport type for the MCP server (default: stdio)
- `MCP_SSE_ENABLED`: Enable SSE transport (default: false)
- `MCP_SSE_ENDPOINT`: SSE endpoint path (default: /sse)
- `N8N_BASE_URL`: Base URL for n8n API (default: http://n8n:5678/api/v1)
- `N8N_API_KEY`: API key for n8n
