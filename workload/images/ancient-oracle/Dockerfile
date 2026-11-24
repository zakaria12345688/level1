# The Ancient Oracle: a read-only Kubernetes MCP server (Python, standard library only).
#
# Build for the cluster's nodes (x86_64), also from an ARM laptop:
#   docker build --platform linux/amd64 -t <registry>/realm/ancient-oracle:<tag> .
FROM python:3.13-alpine

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Runtime shims for the slim image (UTF-8 logs, tolerant JSON), loaded at start-up.
COPY runtime/ /usr/local/lib/python3.13/site-packages/

WORKDIR /app
COPY oracle/ /app/oracle/

USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["python3", "-m", "oracle"]
