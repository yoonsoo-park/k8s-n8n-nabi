const axios = require("axios");

/**
 * A tool that makes HTTP requests
 */
const tool = {
  name: "http_request",
  description: "Make HTTP requests to external APIs",
  parameters: {
    type: "object",
    properties: {
      method: {
        type: "string",
        enum: ["GET", "POST", "PUT", "DELETE"],
        description: "The HTTP method to use",
      },
      url: {
        type: "string",
        description: "The URL to send the request to",
      },
      headers: {
        type: "object",
        description: "HTTP headers to include in the request",
        additionalProperties: {
          type: "string",
        },
      },
      data: {
        type: "object",
        description: "Data to send in the request body (for POST/PUT)",
      },
    },
    required: ["method", "url"],
  },
  async handler(params) {
    try {
      const response = await axios({
        method: params.method,
        url: params.url,
        headers: params.headers || {},
        data: params.data || {},
      });

      return {
        status: response.status,
        headers: response.headers,
        data: response.data,
      };
    } catch (error) {
      if (error.response) {
        return {
          error: true,
          status: error.response.status,
          message: error.message,
          data: error.response.data,
        };
      }
      return {
        error: true,
        message: error.message,
      };
    }
  },
};

module.exports = { tool };
