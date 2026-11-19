# The server's container (Phase 2 commit 4). Build from the repo root — the
# server depends on packages/math_core by path:
#
#   docker build -f server/Dockerfile -t math-trainer-server .
#
# Stage 1 compiles an AOT binary; stage 2 holds only that binary and the
# runtime files the Dart image prepares in /runtime (a few MB, no SDK).
FROM dart:3.14 AS build
WORKDIR /src

# Dependencies first, so a code change does not refetch them.
COPY packages/math_core/pubspec.yaml packages/math_core/
COPY server/pubspec.yaml server/pubspec.lock server/
RUN cd server && dart pub get

COPY packages/math_core/lib packages/math_core/lib
COPY server/bin server/bin
COPY server/lib server/lib
RUN cd server && dart pub get --offline \
  && dart compile exe bin/server.dart -o /src/server.exe

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /src/server.exe /app/server
# Configuration only from the environment (server/lib/src/config.dart).
EXPOSE 8080
CMD ["/app/server"]
