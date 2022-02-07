import puck/payment
import puck/sheets
import puck/config.{Config}
import puck/web/logger
import puck/web/static
import puck/web/templates.{Templates}
import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/http/service.{Service}
import gleam/bit_builder.{BitBuilder}
import gleam/erlang/file
import gleam/bit_string
import gleam/result
import gleam/string
import gleam/json
import gleam/io

pub type State {
  State(templates: Templates, config: Config)
}

pub fn service(config: Config) -> Service(BitString, BitBuilder) {
  let state = State(config: config, templates: templates.load(config))

  router(_, state)
  |> service.map_response_body(bit_builder.from_string)
  |> logger.middleware
  |> static.middleware
  |> service.prepend_response_header("made-with", "Gleam")
  |> service.prepend_response_header("x-robots-tag", "noindex")
}

fn router(request: Request(BitString), state: State) -> Response(String) {
  case request.path_segments(request) {
    ["2022"] -> attendance(request, state)
    ["licence"] -> licence(state)
    ["the-pal-system"] -> pal_system(state)
    ["api", "payment", key] -> payments(request, key, state.config)
    _ -> not_found()
  }
  |> result.map_error(error_to_response(_, request))
  |> unwrap_both
}

fn attendance(request: Request(BitString), state: State) {
  case request.method {
    http.Get -> attendance_form(state)
    http.Post -> register_attendance(request, state)
    _ -> Error(HttpMethodNotAllowed)
  }
}

fn attendance_form(state: State) {
  let html = state.templates.home()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
  |> Ok
}

fn register_attendance(request: Request(BitString), state: State) {
  // TODO: Generate reference code
  // TODO: Extract parameters
  // TODO: Validate (re-rendering the form if it fails)
  // TODO: Save to sheets
  // TODO: Present (and email?) transfer information to the user
  todo
}

fn licence(state: State) {
  let html = state.templates.licence()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
  |> Ok
}

fn pal_system(state: State) {
  let html = state.templates.pal_system()
  response.new(200)
  |> response.prepend_header("content-type", "text/html")
  |> response.set_body(html)
  |> Ok
}

fn not_found() {
  response.new(404)
  |> response.set_body("There's nothing here...")
  |> Ok
}

type WebError {
  UnexpectedJson(json.DecodeError)
  SaveFailed(sheets.Error)
  HttpMethodNotAllowed
}

// TODO: verify key
// TODO: tests
fn payments(request: Request(BitString), _key: String, config: Config) {
  try payment =
    payment.from_json(request.body)
    |> result.map_error(UnexpectedJson)
  try _ =
    payment
    |> sheets.append_payment(config)
    |> result.map_error(SaveFailed)
  Ok(response.new(200))
}

fn unwrap_both(result: Result(a, a)) -> a {
  case result {
    Ok(value) -> value
    Error(value) -> value
  }
}

fn error_to_response(
  error: WebError,
  request: Request(BitString),
) -> Response(String) {
  case error {
    HttpMethodNotAllowed -> response.new(405)

    UnexpectedJson(_) -> {
      request.body
      |> bit_string.to_string
      |> result.unwrap("")
      |> string.append("ERROR: Unexpected JSON: ", _)
      |> io.println
      response.new(400)
    }

    SaveFailed(error) -> {
      io.print("ERROR: Save failed: ")
      io.debug(error)
      response.new(500)
    }
  }
}
