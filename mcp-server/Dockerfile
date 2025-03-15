FROM node:18-alpine

WORKDIR /app

# Install necessary dependencies
RUN apk add --no-cache python3 make g++ git

# Clone MCP server quickstart repository or use your company's internal npm package
# Option 1: Using the MCP quickstart
RUN git clone https://github.com/anthropics/anthropic-cookbook.git /tmp/anthropic-cookbook
WORKDIR /tmp/anthropic-cookbook/tools/mcp/quickstart_server
RUN npm install

# Option 2: If using your company's internal npm package (uncomment and adapt)
# COPY package.json .
# RUN npm install @ncino/cli
# RUN npm install

# Copy your MCP server configuration and tool definitions
COPY tools/ /app/tools/
COPY server.js /app/

EXPOSE 3000

CMD ["node", "server.js"] 