FROM hiromuhota/webspoon:latest

WORKDIR /etl

# Copy entrypoint.
COPY --chmod=755 entrypoint.webspoon.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
