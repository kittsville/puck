import puck/payment
import puck/sheets
import puck/config.{Config}
import puck/web/logger
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/file
import gleam/bit_string
import gleam/result
import gleam/string

pub fn service(config: Config) -> Service(BitString, BitBuilder) {
  router(_, config)
  |> service.prepend_response_header("made-with", "Gleam")
  |> service.map_response_body(bit_builder.from_string)
  |> logger.middleware
  // |> static.middleware()
}

fn router(request: Request(BitString), config: Config) -> Response(String) {
  case request.path_segments(request) {
    [] -> home()
    ["api", "payment", key] -> payments(request, key, config)
    _ -> not_found()
  }
}

fn home() {
  response.new(200)
  |> response.set_body("Hello, Joe!")
}

fn not_found() {
  response.new(404)
  |> response.set_body("There's nothing here...")
}

// TODO: nicer error handling
// TODO: verify key
// TODO: tests
fn payments(request: Request(BitString), _key: String, config: Config) {
  {
    try json = bit_string.to_string(request.body)
    try payment =
      payment.from_json(json)
      |> result.nil_error
    payment
    |> sheets.append_payment(config)
    |> result.map(fn(_) { response.new(200) })
    |> result.nil_error
  }
  |> result.unwrap(response.new(400))
}
