# Gateway nginx del bounded context {{BC_KEY}}.
# TODO({{REPO_NAME}}): ajustar versión base y endurecer (usuario no-root, etc.).
FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/healthz || exit 1
