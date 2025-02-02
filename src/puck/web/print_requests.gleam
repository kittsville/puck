import gleam/http
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/int
import gleam/io
import gleam/string

fn format_log_line(
  request: Request(a),
  response: Response(b),
  elapsed: Int,
) -> String {
  let elapsed = case elapsed > 1000 {
    True -> string.append(int.to_string(elapsed / 1000), "ms")
    False -> string.append(int.to_string(elapsed), "µs")
  }

  string.concat([
    request.method
    |> http.method_to_string
    |> string.uppercase,
    " ",
    request.path,
    " ",
    int.to_string(response.status),
    " sent in ",
    elapsed,
  ])
}

pub fn middleware(request: Request(a), next: fn() -> Response(b)) -> Response(b) {
  let before = now()
  let response = next()
  let elapsed = convert_time_unit(now() - before, Native, Microsecond)
  io.println(format_log_line(request, response, elapsed))
  response
}

type TimeUnit {
  Native
  Microsecond
}

external fn now() -> Int =
  "erlang" "monotonic_time"

external fn convert_time_unit(Int, TimeUnit, TimeUnit) -> Int =
  "erlang" "convert_time_unit"
