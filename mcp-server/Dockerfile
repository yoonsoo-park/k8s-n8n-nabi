FROM node:18-alpine

WORKDIR /app

# Install necessary dependencies
RUN apk add --no-cache python3 make g++ git

# Copy package.json and install dependencies
COPY package.json .
RUN npm install

# Copy server code and tools
COPY server.js .
COPY tools/ ./tools/

# Expose the MCP server port
EXPOSE 3000

# Start the MCP server
CMD ["node", "server.js"] 