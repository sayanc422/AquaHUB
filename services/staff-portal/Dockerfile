# syntax=docker/dockerfile:1.7
# ---------- build ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
# Dependency layer first, same reason as aquatics-advisor's requirements.txt:
# the pom changes far less often than the servlets/JSPs.
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -q -B dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -q -B package -DskipTests

# ---------- runtime ----------
# quay.io/wildfly/wildfly, not distroless -- and not even python:3.11-slim
# minimal. This is the point of the service: a full JBoss/WildFly install,
# with a shell and a package manager, is the largest attack surface in the
# platform, larger than aquatics-advisor's. Containerising it correctly
# anyway -- console logging, a numeric non-root UID, startup probes for a
# slow boot, graceful shutdown -- is "the exercise that connects this project
# to production work" (docs/architecture.md), not something to work around.
#
# The official image already runs as a non-root user (verified by actually
# running `id` inside it while building this, not assumed) -- see the pod
# securityContext in platform-repo/dev/staff-portal/deployment.yaml for the
# exact UID/GID that was found.
FROM quay.io/wildfly/wildfly:33.0.1.Final-jdk21

# WildFly's default standalone.xml logs to
# standalone/log/server.log, not stdout. Kubernetes only ever sees container
# stdout/stderr, so without this change every log line this service ever
# writes would be invisible to `kubectl logs` -- the exact "stdout logging"
# requirement docs/architecture.md calls out by name for this service.
# CONSOLE is already a handler in the default logging profile; this just
# raises its level and drops the periodic-rotating-file handler from the
# root logger so nothing is duplicated or lost silently to a file no one
# is watching in a container.
USER root
RUN /opt/jboss/wildfly/bin/jboss-cli.sh --echo-command <<'EOF'
embed-server --std-out=echo
/subsystem=logging/root-logger=ROOT:write-attribute(name=handlers,value=[CONSOLE])
/subsystem=logging/console-handler=CONSOLE:write-attribute(name=level,value=INFO)
stop-embedded-server
EOF
# The embed-server run above already wrote one config-history entry
# (standalone_xml_history/current/standalone.v2.xml, alongside the base
# image's own v1). Left in place, the container's real first boot tries to
# rotate that non-empty "current" directory and fails with
# WFLYCTL0056/DirectoryNotEmptyException -- non-fatal (the server still
# starts, just without a history backup) but a real, confusing error on
# every fresh container, found by actually running the image. Clearing the
# history here means the container's first boot really is WildFly's first
# boot, not its second.
RUN rm -rf /opt/jboss/wildfly/standalone/configuration/standalone_xml_history/*

# ROOT.war, not staff-portal.war: WildFly derives the context path from the
# deployment's filename, so staff-portal.war would only answer under
# /staff-portal/healthz, /staff-portal/orders, etc. -- silently breaking
# every k8s probe path and every other service's /healthz convention in this
# platform. Found by curling the running container, not by reading the
# Dockerfile: a build that "works" still deployed at the wrong path.
COPY --from=build /build/target/staff-portal.war /opt/jboss/wildfly/standalone/deployments/ROOT.war
# The embed-server step above ran as root and touched standalone/log (writing
# the log-config change) and standalone/configuration -- and WildFly's first
# real boot touches standalone/data and standalone/tmp too. Whichever of
# those didn't already exist gets created root-owned, and the container then
# fails at boot with "Directory .../standalone/data/content is not writable"
# once it drops to the non-root jboss user -- found by actually running the
# image, not by reading the Dockerfile. Reasserting ownership of the whole
# standalone/ tree is the fix, not just the WAR file.
RUN chown -R jboss:jboss /opt/jboss/wildfly/standalone

USER jboss
EXPOSE 8080
ENTRYPOINT ["/opt/jboss/wildfly/bin/standalone.sh", "-b", "0.0.0.0"]
