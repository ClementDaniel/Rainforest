# -------- Stage 1: Builder --------
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libffi-dev \
        libssl-dev \
        python3-dev \
        gcc \
        g++ \
        && rm -rf /var/lib/apt/lists/*

# Upgrade pip, setuptools, and wheel
RUN pip install --upgrade pip setuptools wheel

# Copy ONLY requirements first (for better caching)
COPY requirements.txt .

# Install dependencies with verbose output
RUN pip install --target=/install --no-cache-dir -r requirements.txt --verbose

# Copy application code
COPY app.py .

# -------- Stage 2: Runtime --------
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local/lib/python3.11/site-packages

# Copy application code
COPY --from=builder /app/app.py .

# Switch to non-root user
USER appuser

# Set PYTHONPATH
ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages

EXPOSE 8080

CMD ["python", "app.py"]
