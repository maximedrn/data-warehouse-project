#!/bin/bash
set -e

# Start WebSpoon (Tomcat with WebSpoon web application).
exec /usr/local/tomcat/bin/catalina.sh run
