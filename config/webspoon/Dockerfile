FROM hiromuhota/webspoon:latest

WORKDIR /etl

# Copy UCanAccess + dependencies into Tomcat lib.
COPY etl/lib/*.jar /usr/local/tomcat/lib/

# Copy entrypoint.
COPY entrypoint.webspoon.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
