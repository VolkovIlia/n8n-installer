FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (cairo for QR code generation)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy bot source code
COPY src/ ./src/

# Run bot via main.py (which sets up environment first)
CMD ["python3", "-u", "src/main.py"]
