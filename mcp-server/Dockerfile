FROM node:20

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source files
COPY tsconfig.json ./
COPY src ./src

# List source directory contents for debugging
RUN echo "Contents of src directory:" && ls -la src
RUN echo "Contents of src/tools directory:" && ls -la src/tools || echo "No src/tools directory found"

# Build TypeScript
RUN npm run build

# List dist directory to verify build output
RUN echo "Contents of dist directory:" && ls -la dist
RUN echo "Contents of dist/tools directory (if exists):" && ls -la dist/tools || echo "No dist/tools directory found"

# Ensure tools directory exists in dist
RUN mkdir -p dist/tools

# Copy ONLY compiled JavaScript tools to dist/tools
RUN find src/tools -name "*.js" -exec cp -v {} dist/tools/ \; || echo "No compiled JS tools found in src/tools"
RUN echo "Copying compiled JS tools from dist/tools (if they exist)..."
RUN find dist/tools -name "*.js" -exec ls -la {} \; || echo "No JS tools found in dist/tools"

# Make sure we only have JS files in dist/tools (remove any TS files that might have been copied)
RUN find dist/tools -name "*.ts" -delete || echo "No TS files to remove"

# Final verification
RUN echo "Final contents of dist/tools:" && ls -la dist/tools || echo "dist/tools remains empty"

# Set production environment
ENV NODE_ENV=production
ENV MCP_TRANSPORT_TYPE=sse

# Debug the directories and file structure
RUN echo "Source directory contents:" && \
    ls -la src/ && \
    echo "Source tools directory contents:" && \
    ls -la src/tools/ && \
    echo "Dist directory contents:" && \
    ls -la dist/ || echo "dist directory not found"

# Create tools directory and copy tool files
RUN mkdir -p dist/tools && \
    cp -r src/tools/*.ts dist/tools/ && \
    echo "Copied TypeScript tools" && \
    ls -la dist/tools/

# Expose the MCP server port
EXPOSE 1991

# Start the MCP server
CMD ["node", "dist/server.js"] 