const { EventSource } = require("eventsource");
const { v4: uuidv4 } = require("uuid");

console.log("Testing MCP server SSE connection...");

// Create an EventSource connection to the SSE endpoint
const eventSource = new EventSource("http://localhost:1991/sse");

// Function to make a tool request using FastMCP protocol
function callTool(toolName, parameters = {}) {
  const requestId = uuidv4();

  console.log(`Calling tool: ${toolName} with request ID: ${requestId}`);

  // Create the JSON-RPC message
  const message = {
    jsonrpc: "2.0",
    id: requestId,
    method: "tool",
    params: {
      name: toolName,
      parameters: parameters,
    },
  };

  // In FastMCP, you send messages through the "message" event
  eventSource.dispatchEvent(
    new Event("message", { data: JSON.stringify(message) })
  );

  return requestId;
}

// Handle connection open
eventSource.onopen = () => {
  console.log("Connected to SSE endpoint!");

  // Call the n8n_list_workflows tool once connected
  callTool("n8n_list_workflows");
};

// Handle messages from the server
eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log("Received SSE message:", data);

  if (data.result && data.result.success) {
    console.log(`✅ Success! Found ${data.result.total} workflow(s).`);
    console.log("Workflows:", data.result.workflows);
  } else if (data.error) {
    console.log("❌ Error:", data.error);
  }

  // Close the connection after receiving a response
  console.log("Closing connection...");
  eventSource.close();
  process.exit(0);
};

// Handle errors
eventSource.onerror = (error) => {
  console.error("SSE Error:", error);
  console.log("\nDebug Information:");
  console.log("1. Make sure the MCP server is running in Docker");
  console.log('2. Check Docker port mapping with "docker ps"');
  console.log(
    "3. The SSE endpoint should be available at http://localhost:1991/sse"
  );
  console.log("4. Check for CORS issues or other network problems");

  eventSource.close();
  process.exit(1);
};

// Set a timeout to abort if no connection is made
setTimeout(() => {
  console.error("Timeout: No response from server after 10 seconds");
  eventSource.close();
  process.exit(1);
}, 10000);
