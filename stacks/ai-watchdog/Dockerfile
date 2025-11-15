FROM python:3.11-slim
WORKDIR /app
COPY app.py /app/
RUN pip install --no-cache-dir flask prometheus_client docker requests
EXPOSE 5000
CMD ["python", "app.py"]
