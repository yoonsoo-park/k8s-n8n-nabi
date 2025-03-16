import axios from "axios";
import { z } from "zod";

// Define the parameter schema
const paramsSchema = z.object({
  active: z
    .boolean()
    .describe("Filter workflows by active status (optional)")
    .optional(),
});

// Infer the type from the schema
type N8nListWorkflowsParams = z.infer<typeof paramsSchema>;

/**
 * A tool that lists all workflows from n8n
 */
const n8nListWorkflowsTool = {
  name: "n8n_list_workflows",
  description: "Lists all workflows available in n8n",
  parameters: paramsSchema,
  execute: async (params: N8nListWorkflowsParams) => {
    try {
      // Get the n8n base URL and API key from environment variables
      const baseUrl = process.env.N8N_BASE_URL || "http://n8n:5678/api/v1";
      const apiKey = process.env.N8N_API_KEY;

      if (!apiKey) {
        return JSON.stringify({
          error: true,
          message: "N8N_API_KEY environment variable is not set.",
        });
      }

      // Construct the URL for the API request to list workflows
      let url = `${baseUrl}/workflows`;
      if (params.active !== undefined) {
        url += `?active=${params.active}`;
      }

      // Make the API request
      const response = await axios({
        method: "GET",
        url: url,
        headers: {
          "X-N8N-API-KEY": apiKey,
        },
      });

      // Return the workflows
      return JSON.stringify({
        success: true,
        workflows: response.data.data,
        total: response.data.data.length,
      });
    } catch (error: any) {
      console.error("Error fetching n8n workflows:", error);

      if (error.response) {
        return JSON.stringify({
          error: true,
          status: error.response.status,
          message: `Failed to fetch workflows: ${error.message}`,
          data: error.response.data,
        });
      }

      return JSON.stringify({
        error: true,
        message: `Failed to fetch workflows: ${error.message}`,
      });
    }
  },
};

export default n8nListWorkflowsTool;
