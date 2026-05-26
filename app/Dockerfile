# Base image — slim = smaller attack surface
FROM python:3.11-slim

# Who maintains this
LABEL maintainer="devops-engineer"
LABEL version="1.0"

# Never run as root inside containers
RUN useradd -m -u 1000 -s /bin/bash appuser

# Working directory
WORKDIR /app

# Copy requirements FIRST
# Why? Docker layer caching
# If requirements don't change, this layer is cached
# Rebuilds only re-run pip install if requirements.txt changed
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Document the port
EXPOSE 5000

# Health check — Docker uses this to monitor container health
# Every 30s, curl the health endpoint
# If it fails 3 times in a row → container marked unhealthy
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" \
    || exit 1

# Start command
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", \
     "--access-logfile", "-", "--error-logfile", "-", "app:app"]
