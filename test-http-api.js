const axios = require("axios");

async function testMcpServer() {
  try {
    console.log("Testing MCP server HTTP API...");

    // Make a JSON-RPC request to the HTTP API endpoint (port 1992 is the API port)
    const response = await axios.post("http://localhost:1992/api", {
      jsonrpc: "2.0",
      id: "1",
      method: "tool",
      params: {
        name: "n8n_list_workflows",
        parameters: {},
      },
    });

    // Print the response
    console.log("MCP Server Response:");
    console.log(JSON.stringify(response.data, null, 2));

    if (response.data.result && response.data.result.success) {
      console.log(
        `✅ Success! Found ${response.data.result.total} workflow(s).`
      );
      if (response.data.result.workflows) {
        console.log("Workflows:");
        response.data.result.workflows.forEach((workflow, index) => {
          console.log(`  ${index + 1}. ${workflow.name} (ID: ${workflow.id})`);
        });
      }
    } else {
      console.log("❌ Failed to list workflows.");
      if (response.data.error) {
        console.error("Error:", response.data.error);
      }
    }
  } catch (error) {
    console.error("Error testing MCP server:");
    if (error.response) {
      console.error(`Status: ${error.response.status}`);
      console.error("Data:", error.response.data);
    } else {
      console.error(error.message);
    }
  }
}

// Run the test
testMcpServer();
