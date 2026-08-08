import gleam/bit_array
import gleam/bytes_tree
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import mist.{type Connection, type ResponseData}
import sqlight

const schema = "
CREATE TABLE IF NOT EXISTS goals (
  id TEXT PRIMARY KEY,
  goal_type TEXT NOT NULL,
  goal_payload TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);"

pub fn main() {
  let database = database_path()
  use connection <- sqlight.with_connection(database)
  let assert Ok(Nil) = sqlight.exec(schema, connection)

  let assert Ok(_) =
    fn(request) { route(request, database) }
    |> mist.new
    |> mist.port(4000)
    |> mist.start

  io.println("ByWhen API listening on http://localhost:4000")
  process.sleep_forever()
}

pub fn route(
  req: Request(Connection),
  database: String,
) -> Response(ResponseData) {
  case req.method, request.path_segments(req) {
    http.Get, ["api", "health"] -> json(200, "{\"status\":\"ok\"}")
    http.Options, ["api", "goals", ..] -> json(204, "")
    http.Post, ["api", "goals"] -> create_goal(req, database)
    http.Get, ["api", "goals", id] -> get_goal(id, database)
    http.Delete, ["api", "goals", id] -> delete_goal(id, database)
    _, _ -> json(404, "{\"error\":\"Not found\"}")
  }
}

fn create_goal(
  req: Request(Connection),
  database: String,
) -> Response(ResponseData) {
  case mist.read_body(req, 64 * 1024) {
    Error(_) -> json(400, "{\"error\":\"The goal payload is invalid.\"}")
    Ok(read) ->
      case bit_array.to_string(read.body) {
        Error(_) ->
          json(400, "{\"error\":\"The goal payload must be UTF-8 JSON.\"}")
        Ok(payload) -> {
          let id = public_id()
          use connection <- sqlight.with_connection(database)
          case
            sqlight.query(
              "INSERT INTO goals (id, goal_type, goal_payload) VALUES (?, 'shared', ?)",
              on: connection,
              with: [sqlight.text(id), sqlight.text(payload)],
              expecting: decode.dynamic,
            )
          {
            Ok(_) -> json(201, "{\"id\":\"" <> id <> "\"}")
            Error(_) ->
              json(500, "{\"error\":\"The goal could not be saved.\"}")
          }
        }
      }
  }
}

fn get_goal(id: String, database: String) -> Response(ResponseData) {
  let payload_decoder = {
    use payload <- decode.field(0, decode.string)
    decode.success(payload)
  }
  use connection <- sqlight.with_connection(database)
  case
    sqlight.query(
      "SELECT goal_payload FROM goals WHERE id = ? LIMIT 1",
      on: connection,
      with: [sqlight.text(id)],
      expecting: payload_decoder,
    )
  {
    Ok([payload]) -> json(200, payload)
    Ok(_) -> json(404, "{\"error\":\"Goal not found.\"}")
    Error(_) -> json(500, "{\"error\":\"The goal could not be loaded.\"}")
  }
}

fn delete_goal(id: String, database: String) -> Response(ResponseData) {
  use connection <- sqlight.with_connection(database)
  case
    sqlight.query(
      "DELETE FROM goals WHERE id = ?",
      on: connection,
      with: [sqlight.text(id)],
      expecting: decode.dynamic,
    )
  {
    Ok(_) -> json(204, "")
    Error(_) -> json(500, "{\"error\":\"The goal could not be deleted.\"}")
  }
}

fn json(status: Int, body: String) -> Response(ResponseData) {
  response.new(status)
  |> response.set_header("content-type", "application/json; charset=utf-8")
  |> response.set_header("access-control-allow-origin", "*")
  |> response.set_header(
    "access-control-allow-methods",
    "GET, POST, DELETE, OPTIONS",
  )
  |> response.set_header("access-control-allow-headers", "content-type")
  |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
}

@external(erlang, "bywhen_id", "public_id")
fn public_id() -> String

@external(erlang, "bywhen_id", "database_path")
fn database_path() -> String
