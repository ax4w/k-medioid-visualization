# Use Bun for better performance
FROM oven/bun:1 as builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json .
COPY bun.lockb* .

# Install dependencies
RUN bun install --frozen-lockfile

# Copy all source files
COPY . .

# Build the application
RUN bun run build

# Use nginx for serving static files
FROM nginx:alpine

# Copy nginx configuration (optional, using default for now)
# COPY nginx.conf /etc/nginx/nginx.conf

# Copy built files to nginx
COPY --from=builder /app/build /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]