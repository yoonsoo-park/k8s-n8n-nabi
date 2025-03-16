const axios = require("axios");
const { EventSource } = require("eventsource");
const { v4: uuidv4 } = require("uuid");

// Function to call the MCP server's n8n_list_workflows tool
async function testMcpServer() {
  try {
    console.log("Testing MCP server connection...");

    // Create an SSE connection to the MCP server
    console.log("Connecting to SSE endpoint at http://localhost:1991/sse...");
    const source = new EventSource("http://localhost:1991/sse");

    // Create a Promise that will resolve with the first message or reject on error
    const messagePromise = new Promise((resolve, reject) => {
      // Listen for messages
      source.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          resolve(data);
        } catch (err) {
          reject(new Error(`Failed to parse message: ${err.message}`));
        }
      };

      // Handle errors
      source.onerror = (err) => {
        reject(
          new Error(`SSE connection error: ${err.message || "Unknown error"}`)
        );
      };

      // Handle successful connection
      source.onopen = () => {
        console.log("Connected to SSE endpoint!");

        // Send a request to call the n8n_list_workflows tool
        console.log("Sending tool request...");
        const toolRequest = {
          jsonrpc: "2.0",
          id: uuidv4(),
          method: "tool",
          params: {
            name: "n8n_list_workflows",
            parameters: {},
          },
        };

        // In a proper SSE client implementation, we'd send this through a backchannel
        // For testing, let's use a direct HTTP request
        axios.post("http://localhost:1991/sse", toolRequest).catch((error) => {
          // This might fail with a 404, which is expected since we're using SSE
          console.log(
            "Sent tool request via HTTP (this might show an expected error)"
          );
        });
      };
    });

    // Set a timeout
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(
        () => reject(new Error("Connection timed out after 10 seconds")),
        10000
      );
    });

    // Wait for the first message or timeout
    const response = await Promise.race([messagePromise, timeoutPromise]);

    // Close the connection
    source.close();
    console.log("Closed SSE connection");

    // Print the response
    console.log("MCP Server Response:");
    console.log(JSON.stringify(response, null, 2));

    if (response.result && response.result.success) {
      console.log(`✅ Success! Found ${response.result.total} workflow(s).`);
    } else {
      console.log("❌ Failed to list workflows.");
      if (response.error) {
        console.error("Error:", response.error);
      }
    }
  } catch (error) {
    console.error("Error testing MCP server:", error.message);
    console.log("\nDebug Information:");
    console.log("1. Make sure the MCP server is running in Docker");
    console.log("2. Check Docker port mapping with 'docker ps'");
    console.log(
      "3. Try accessing the SSE endpoint directly in browser: http://localhost:1991/sse"
    );
    console.log(
      "4. Check your Docker networks with 'docker network ls' and 'docker network inspect'"
    );
    console.log(
      "5. Verify the container is accessible with 'docker exec -it n8n-nabi-mcp-server-1 curl localhost:1991/sse'"
    );
  }
}

// Run the test
testMcpServer().catch(console.error);
