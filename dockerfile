# -------- Stage 1: Builder --------
FROM python:3.11-slim AS builder

WORKDIR /app

# Install dependencies system-wide
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# -------- Stage 2: Runtime --------
FROM python:3.11-slim

WORKDIR /app

# Create non-root user (Debian slim)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy app and dependencies from builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /app /app

# Switch to non-root user
USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
