FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir prometheus-client

# Copy application
COPY failover.py .

CMD ["python", "failover.py"]
