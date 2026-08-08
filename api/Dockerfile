FROM ghcr.io/gleam-lang/gleam:v1.12.0-erlang-alpine AS build
WORKDIR /app
COPY gleam.toml manifest.toml* ./
RUN gleam deps download
COPY src src
RUN gleam export erlang-shipment

FROM erlang:28-alpine
WORKDIR /app
RUN apk add --no-cache sqlite-libs
COPY --from=build /app/build/erlang-shipment ./
EXPOSE 4000
CMD ["./entrypoint.sh", "run"]

