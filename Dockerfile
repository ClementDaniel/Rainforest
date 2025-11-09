# -------- Stage 1: Build --------
FROM python:3.11-alpine AS builder

WORKDIR /app

# Install build dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Copy application code
COPY app.py .

# -------- Stage 2: Runtime --------
FROM python:3.11-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Copy only necessary files from builder
COPY --from=builder /app /app
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
