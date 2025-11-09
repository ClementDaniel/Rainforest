# -------- Stage 1: Builder --------
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies for compiling Python packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libffi-dev \
        libssl-dev \
        python3-dev \
        && rm -rf /var/lib/apt/lists/*

# Copy requirements first for caching
COPY . .

# Install dependencies into /install (isolated location)
RUN pip install --prefix=/install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# -------- Stage 2: Runtime --------
FROM python:3.11-slim

WORKDIR /app

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY --from=builder /app /app

# Switch to non-root user
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
