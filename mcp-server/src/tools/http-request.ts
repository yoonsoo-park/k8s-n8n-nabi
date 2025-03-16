import axios from "axios";
import { z } from "zod";

// Define the parameter schema
const paramsSchema = z.object({
  method: z
    .enum(["GET", "POST", "PUT", "DELETE"])
    .describe("The HTTP method to use"),
  url: z.string().describe("The URL to send the request to"),
  headers: z
    .record(z.string())
    .describe("HTTP headers to include in the request")
    .optional(),
  data: z
    .record(z.any())
    .describe("Data to send in the request body (for POST/PUT)")
    .optional(),
});

// Infer the type from the schema
type HttpRequestParams = z.infer<typeof paramsSchema>;

/**
 * A tool that makes HTTP requests
 */
const httpRequestTool = {
  name: "http_request",
  description: "Make HTTP requests to external APIs",
  parameters: paramsSchema,
  execute: async (params: HttpRequestParams) => {
    try {
      const response = await axios({
        method: params.method,
        url: params.url,
        headers: params.headers || {},
        data: params.data || {},
      });

      return JSON.stringify({
        status: response.status,
        headers: response.headers,
        data: response.data,
      });
    } catch (error: any) {
      if (error.response) {
        return JSON.stringify({
          error: true,
          status: error.response.status,
          message: error.message,
          data: error.response.data,
        });
      }
      return JSON.stringify({
        error: true,
        message: error.message,
      });
    }
  },
};

export default httpRequestTool;
