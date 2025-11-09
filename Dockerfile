# Use Bun for both building and running
FROM oven/bun:1

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

# Expose the port the app runs on
EXPOSE 3000

# Command to run the application
CMD ["bun", "build/index.js"]