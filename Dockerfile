FROM ghcr.io/gleam-lang/gleam:v0.26.0-rc1-erlang-alpine

# Add project code
COPY . /build/

# Compile the application
RUN cd /build \
  && gleam export erlang-shipment \
  && mv build/erlang-shipment /app \
  && rm -r /build \
  && addgroup -S puck \
  && adduser -S puck -G puck \
  && chown -R puck /app

USER puck
WORKDIR /app
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run", "server"]
