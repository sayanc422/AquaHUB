# syntax=docker/dockerfile:1.7
# ---------- build ----------
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
# dependency layer first: pom rarely changes, src changes every commit
COPY pom.xml .
RUN --mount=type=cache,target=/root/.m2 mvn -B -q dependency:go-offline
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -q clean package -DskipTests

# ---------- runtime ----------
# distroless: no shell, no package manager, nothing for an attacker to pivot with.
# Cost: no `kubectl exec sh` into this pod. Debug with an ephemeral container instead.
FROM gcr.io/distroless/java21-debian12:nonroot
WORKDIR /app
COPY --from=build /build/target/catalog-service-*.jar /app/app.jar
USER nonroot:nonroot
EXPOSE 8080
# MaxRAMPercentage, not -Xmx: the JVM must size its heap from the cgroup limit,
# not from the node's total memory. Without this the JVM sees the host's RAM,
# sizes a heap far above the container limit, and the kernel OOM-kills the
# process -> exit code 137, which Kubernetes reports as OOMKilled.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=70 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -Djava.security.egd=file:/dev/./urandom"
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
