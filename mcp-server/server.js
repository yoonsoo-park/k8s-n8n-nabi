const { Server } = require("@anthropic-ai/model-context-protocol");
const fs = require("fs");
const path = require("path");

// Load tool definitions from tools directory
const toolsDir = path.join(__dirname, "tools");
const toolFiles = fs
  .readdirSync(toolsDir)
  .filter((file) => file.endsWith(".js"));

const tools = [];
for (const file of toolFiles) {
  const toolModule = require(path.join(toolsDir, file));
  tools.push(toolModule.tool);
}

// Create the MCP server
const server = new Server({
  tools,
  port: process.env.MCP_SERVER_PORT || 3000,
  logLevel: process.env.MCP_SERVER_LOG_LEVEL || "info",
});

// Start the server
server
  .listen()
  .then(() => {
    console.log(`MCP Server is running on port ${server.port}`);
  })
  .catch((err) => {
    console.error("Failed to start MCP server:", err);
    process.exit(1);
  });
