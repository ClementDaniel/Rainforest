# -------- Stage 1: Build --------
FROM python:3.11-alpine AS builder

WORKDIR /app

# Install dependencies system-wide
COPY . .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# -------- Stage 2: Runtime --------
FROM python:3.11-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Copy application and dependencies
COPY --from=builder /usr/local /usr/local
COPY --from=builder /app /app

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
