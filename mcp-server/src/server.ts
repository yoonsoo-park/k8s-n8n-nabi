import { FastMCP } from "fastmcp";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

// Get the current directory
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Creating the FastMCP server
const server = new FastMCP({
  name: "n8n MCP Server",
  version: "1.0.0",
});

// Configure server events
server.on("connect", (event) => {
  console.log(`Client connected with session`);
});

server.on("disconnect", (event) => {
  console.log(`Client disconnected`);
});

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

    // Count tools loaded in a more reliable way by keeping track of successful additions
    let successfullyLoadedTools = 0;

    // Import each tool
    for (const file of toolFiles) {
      try {
        console.log(`Loading tool from file: ${file}`);
        const toolModule = await import(path.join(toolsDir, file));

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

      // Start with SSE transport
      server.start({
        transportType: "sse",
        sse: {
          endpoint: formattedSseEndpoint as `/${string}`,
          port: serverPort,
        },
      });

      console.log(
        `MCP Server is running with SSE transport on port ${serverPort}`
      );
      console.log(
        `SSE endpoint available at http://localhost:${serverPort}${formattedSseEndpoint}`
      );
      console.log(
        `server is running on SSE at http://localhost:${serverPort}${formattedSseEndpoint}`
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
