import { FastMCP } from "fastmcp";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
// Start of HTTP server setup for /api testing
import http from "http";

// Get the current directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Create a custom tool registry to store tools for /api testing
const toolRegistry = new Map();

// Creating the FastMCP server
const server = new FastMCP({
  name: "n8n MCP Server",
  version: "1.0.0",
});

// Override the addTool method to also store tools in our registry
// this is used to verify that the tool is added to the server in the logs
const originalAddTool = server.addTool.bind(server);
server.addTool = (tool) => {
  // Store the tool in our registry
  if (tool && tool.name) {
    console.log(`Storing tool in registry: ${tool.name}`);
    toolRegistry.set(tool.name, tool);
  }

  // Call the original method (do not remove)
  return originalAddTool(tool);
};

// Configure server events
server.on("connect", (event) => {
  console.log(`Client connected with session`);
});

server.on("disconnect", (event) => {
  console.log(`Client disconnected`);
});

// 💀💀 Start of HTTP server setup
// Simple HTTP server for JSON-RPC
// this is used for testing the MCP server via the /api endpoint
function setupHttpServer() {
  const httpServer = http.createServer(async (req, res) => {
    // Enable CORS
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight OPTIONS request
    if (req.method === "OPTIONS") {
      res.writeHead(204);
      res.end();
      return;
    }

    // Only handle POST requests to /api
    if (req.method === "POST" && req.url === "/api") {
      let body = "";

      // Collect request body
      req.on("data", (chunk) => {
        body += chunk.toString();
      });

      // Process request
      req.on("end", async () => {
        try {
          // Parse JSON body
          const jsonBody = JSON.parse(body);
          console.log("Received JSON-RPC request:", jsonBody);

          // Set content type
          res.setHeader("Content-Type", "application/json");

          // Validate it's a JSON-RPC request
          if (
            !jsonBody.jsonrpc ||
            jsonBody.jsonrpc !== "2.0" ||
            !jsonBody.method
          ) {
            res.writeHead(400);
            res.end(
              JSON.stringify({
                jsonrpc: "2.0",
                error: { code: -32600, message: "Invalid Request" },
                id: jsonBody.id || null,
              })
            );
            return;
          }

          // Handle tool calls
          if (
            jsonBody.method === "tool" &&
            jsonBody.params &&
            jsonBody.params.name
          ) {
            const toolName = jsonBody.params.name;
            const params = jsonBody.params.parameters || {};

            console.log(`Calling tool: ${toolName} with parameters:`, params);

            try {
              // Try different ways to call the tool based on FastMCP's API
              let result;

              // First check our custom registry
              if (toolRegistry.has(toolName)) {
                console.log(`Found tool '${toolName}' in custom registry`);
                const tool = toolRegistry.get(toolName);

                if (tool.execute && typeof tool.execute === "function") {
                  result = await tool.execute(params);
                } else {
                  throw new Error(
                    `Tool '${toolName}' does not have an execute method`
                  );
                }
              }
              // Then try other methods
              else {
                // Cast server to any to bypass TypeScript restrictions
                const serverAny = server as any;

                // Debug server properties
                console.log("Server properties:", Object.keys(serverAny));

                if (serverAny._tools) {
                  console.log(
                    "Available tools in _tools:",
                    Object.keys(serverAny._tools)
                  );
                }

                if (serverAny.tools) {
                  console.log(
                    "Available tools in tools:",
                    Object.keys(serverAny.tools)
                  );
                }

                // First try the direct tool execution if it exists
                if (typeof serverAny.executeTool === "function") {
                  console.log("Using server.executeTool method");
                  result = await serverAny.executeTool(toolName, params);
                }
                // Then try to find the tool and call its execute method
                else {
                  const tools = serverAny._tools || serverAny.tools;

                  if (
                    tools &&
                    tools[toolName] &&
                    typeof tools[toolName].execute === "function"
                  ) {
                    console.log(
                      `Found tool '${toolName}' in tools collection, executing`
                    );
                    result = await tools[toolName].execute(params);
                  }
                  // Last resort, try to call the tool directly
                  else if (
                    serverAny[toolName] &&
                    typeof serverAny[toolName] === "function"
                  ) {
                    console.log(
                      `Found tool '${toolName}' as a direct method on server`
                    );
                    result = await serverAny[toolName](params);
                  } else {
                    console.log(
                      "Available server methods:",
                      Object.getOwnPropertyNames(
                        Object.getPrototypeOf(serverAny)
                      )
                    );
                    throw new Error(
                      `Tool '${toolName}' not found or not executable`
                    );
                  }
                }
              }

              res.writeHead(200);
              res.end(
                JSON.stringify({
                  jsonrpc: "2.0",
                  result,
                  id: jsonBody.id,
                })
              );
            } catch (error: any) {
              console.error(`Error calling tool ${toolName}:`, error);
              res.writeHead(500);
              res.end(
                JSON.stringify({
                  jsonrpc: "2.0",
                  error: {
                    code: -32603,
                    message: error.message || "Internal error",
                    data: { toolName },
                  },
                  id: jsonBody.id,
                })
              );
            }
            return;
          }

          // Handle other methods
          res.writeHead(400);
          res.end(
            JSON.stringify({
              jsonrpc: "2.0",
              error: { code: -32601, message: "Method not found" },
              id: jsonBody.id || null,
            })
          );
        } catch (error: any) {
          console.error("Error processing JSON-RPC request:", error);
          res.writeHead(500);
          res.end(
            JSON.stringify({
              jsonrpc: "2.0",
              error: { code: -32700, message: error.message || "Parse error" },
              id: null,
            })
          );
        }
      });
    } else {
      // Not found
      res.writeHead(404);
      res.end(
        JSON.stringify({
          jsonrpc: "2.0",
          error: { code: -32600, message: "Not Found" },
          id: null,
        })
      );
    }
  });

  return httpServer;
}
// End of HTTP server setup 💀💀

// Determine environment
const isProd = process.env.NODE_ENV === "production";
console.log(`Running in ${isProd ? "PRODUCTION" : "DEVELOPMENT"} mode`);

// In Docker, __dirname is in dist, so we need to look for tools in dist/tools
// In development, __dirname is in src, so we use __dirname/tools
const toolsDir = isProd
  ? path.join(__dirname, "tools") // In production, this resolves to dist/tools
  : path.join(__dirname, "tools"); // In development, this resolves to src/tools

// List all directories to help debug
console.log("Current directory:", __dirname);
console.log("Tools directory:", toolsDir);

// Function to dynamically import tools
const loadTools = async () => {
  try {
    // Check if the tools directory exists
    if (!fs.existsSync(toolsDir)) {
      console.error(`Tools directory not found: ${toolsDir}`);
      // Try to find tools in alternative locations
      const possiblePaths = [
        path.join(process.cwd(), "dist/tools"),
        path.join(process.cwd(), "src/tools"),
        path.join(__dirname, "../src/tools"),
        path.join(__dirname, "../dist/tools"),
      ];

      console.log("Searching for tools in alternative locations:");
      let successfullyLoadedTools = 0;

      for (const testPath of possiblePaths) {
        console.log(`Checking ${testPath}...`);
        if (fs.existsSync(testPath)) {
          console.log(`Found tools directory at ${testPath}`);
          const files = fs.readdirSync(testPath);
          console.log(`Files in directory: ${files.join(", ")}`);

          // Try loading tools from this directory - filter for JS only in production
          const toolFilesToLoad = files.filter((f) =>
            isProd ? f.endsWith(".js") : f.endsWith(".ts") || f.endsWith(".js")
          );

          for (const file of toolFilesToLoad) {
            try {
              console.log(`Attempting to load tool: ${file}`);
              const toolModule = await import(path.join(testPath, file));
              server.addTool(toolModule.default);
              console.log(`Successfully loaded tool from ${file}`);
              successfullyLoadedTools++;
            } catch (err) {
              console.error(`Failed to load tool ${file}:`, err);
            }
          }
        }
      }

      // Log the count from our reliable counter
      console.log(
        `Loaded ${successfullyLoadedTools} tools successfully from fallback locations`
      );
      return;
    }

    console.log(`Found tools directory at: ${toolsDir}`);

    // List all files in the tools directory to debug
    const allFiles = fs.readdirSync(toolsDir);
    console.log(`All files in tools directory: ${allFiles.join(", ")}`);

    // Get TypeScript files in development mode or JavaScript files in production mode
    const toolFiles = allFiles.filter(
      (file) =>
        isProd
          ? file.endsWith(".js") // Only load .js files in production
          : file.endsWith(".ts") || file.endsWith(".js") // Load both in development
    );

    if (toolFiles.length === 0) {
      console.warn(
        `No ${isProd ? ".js" : ".ts or .js"} files found in ${toolsDir}`
      );
      return;
    }

    console.log(
      `Found ${toolFiles.length} tool files: ${toolFiles.join(", ")}`
    );

    // Count tools loaded in a more reliable way by keeping track of successful addition. it is a bit barbaric but it is ok for now.
    let successfullyLoadedTools = 0;

    // Import each tool
    for (const file of toolFiles) {
      try {
        console.log(`Loading tool from file: ${file}`);
        const toolModule = await import(path.join(toolsDir, file));

        console.log("Tool module content:", Object.keys(toolModule));
        console.log("Default export:", toolModule.default);

        if (toolModule.default && toolModule.default.name) {
          console.log(`Tool name from module: ${toolModule.default.name}`);
        }

        if (!toolModule.default) {
          console.warn(
            `No default export in ${file}, trying to find tool object`
          );
          // Try to find a tool object if there's no default export
          if (toolModule.tool) {
            server.addTool(toolModule.tool);
            console.log(`Added tool from module.tool in ${file}`);
            successfullyLoadedTools++;
          } else {
            console.error(`No tool found in ${file}`);
          }
        } else {
          server.addTool(toolModule.default);
          console.log(`Added tool from default export in ${file}`);
          successfullyLoadedTools++;
        }
      } catch (err) {
        console.error(`Error importing tool from ${file}:`, err);
      }
    }

    // Log the count from our reliable counter
    console.log(`Loaded ${successfullyLoadedTools} tools successfully`);

    // Inspect server object to better understand the structure
    console.log("Server keys:", Object.keys(server));

    // Check a few common properties where tools might be stored
    if (successfullyLoadedTools > 0) {
      console.log(
        "Tools were successfully added but may not be correctly stored in FastMCP"
      );

      // Try different properties where tools might be stored
      const serverAny = server as any;

      if (serverAny._tools) {
        console.log(
          `Found ${Object.keys(serverAny._tools).length} tools in server._tools`
        );
      }

      if (serverAny.tools) {
        console.log(
          `Found ${Object.keys(serverAny.tools).length} tools in server.tools`
        );
      }

      // Log the entire server object (non-recursive) to help debug
      console.log(
        "Server object (non-recursive):",
        Object.fromEntries(
          Object.entries(serverAny)
            .filter(([key]) => !key.startsWith("_"))
            .map(([key, value]) => [key, typeof value])
        )
      );
    }

    // Attempt to verify tools using FastMCP's method if available
    try {
      // @ts-ignore
      if (server.getTools && typeof server.getTools === "function") {
        // @ts-ignore
        const serverTools = server.getTools();
        console.log(
          `Server reports ${Object.keys(serverTools).length} tools available`
        );
      } else {
        // Attempt alternative checks
        // @ts-ignore
        const toolCount = server.tools ? Object.keys(server.tools).length : 0;
        if (toolCount > 0) {
          console.log(`Verified ${toolCount} tools from server.tools property`);
        }
      }
    } catch (error) {
      console.log("Note: Could not verify tool count using FastMCP methods");
    }
  } catch (error) {
    console.error("Error loading tools:", error);
  }
};

// Load tools and start the server
const start = async () => {
  try {
    await loadTools();

    // Determine transport type from environment
    const useSSE =
      process.env.MCP_TRANSPORT_TYPE === "sse" ||
      process.env.MCP_SSE_ENABLED === "true";

    // Default port now 1991 instead of 3000
    const serverPort = Number(process.env.MCP_SERVER_PORT || 1991);

    if (useSSE) {
      // Ensure SSE endpoint starts with a slash
      const sseEndpoint = process.env.MCP_SSE_ENDPOINT || "/sse";
      const formattedSseEndpoint = sseEndpoint.startsWith("/")
        ? sseEndpoint
        : `/${sseEndpoint}`;

      console.log(`Starting server with SSE transport on port ${serverPort}`);

      // Create HTTP server for API endpoint /api testing
      const httpServer = setupHttpServer();

      // Start with SSE transport
      server.start({
        transportType: "sse",
        sse: {
          endpoint: formattedSseEndpoint as `/${string}`,
          port: serverPort,
        },
      });

      // Start the HTTP server on a different port to avoid conflicts for /api testing
      const apiPort = serverPort + 1;
      httpServer.listen(apiPort, () => {
        console.log(
          `HTTP JSON-RPC API available at http://localhost:${apiPort}/api`
        );
      });

      console.log(
        `MCP Server is running with SSE transport on port ${serverPort}`
      );
      console.log(
        `SSE endpoint available at http://localhost:${serverPort}${formattedSseEndpoint}`
      );

      // Log additional information about how to interact with the server for /api testing
      console.log(
        `To test the server, use the HTTP JSON-RPC endpoint at http://localhost:${apiPort}/api`
      );
      console.log(
        `Example request: POST /api with JSON body: {"jsonrpc":"2.0","id":"1","method":"tool","params":{"name":"n8n_list_workflows","parameters":{}}}`
      );
    } else {
      console.log("Starting server with stdio transport");

      // Start with stdio transport
      server.start({
        transportType: "stdio",
      });

      console.log(`MCP Server is running with stdio transport`);
    }
  } catch (error) {
    console.error("Failed to start MCP server:", error);
    process.exit(1);
  }
};

start();
