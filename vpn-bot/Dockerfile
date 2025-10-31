FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/

# Health check
HEALTHCHECK --interval=60s --timeout=5s \
  CMD python3 -c "import sys; sys.exit(0)"

# Run bot
CMD ["python3", "-m", "src.main"]
