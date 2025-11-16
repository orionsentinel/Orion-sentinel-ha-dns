FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir requests prometheus-client

# Create data directory
RUN mkdir -p /app/data

# Copy application
COPY analytics.py .

CMD ["python", "analytics.py"]
