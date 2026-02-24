import credentials.{type Credentials}
import formal/form.{type Form}
import gleam/dynamic/decode
import gleam/http/request
import gleam/json
import gleam/option.{type Option}
import gleam/result
import lustre/effect.{type Effect}
import rsvp

pub type LoginForm {
  LoginForm(
    form: Form(LoginData),
    active: Bool,
    url: String,
    errors: List(rsvp.Error),
  )
}

pub type LoginData {
  LoginData(email: String, password: String)
}

pub fn new(url) -> LoginForm {
  LoginForm(
    form.new({
      use email <- form.field("email", form.parse_email)
      // TODO: min 8, etc.
      use password <- form.field(
        "password",
        form.parse_string
          |> form.check_not_empty,
      )

      form.success(LoginData(email:, password:))
    }),
    True,
    url,
    [],
  )
}

/// Decode the response of the login via API
fn decode_login(url, email) -> decode.Decoder(Credentials) {
  use auth_token <- decode.field("auth_token", decode.string)
  use refresh_token <- decode.field("refresh_token", decode.string)
  use csrf_token <- decode.field("csrf_token", decode.string)
  decode.success(credentials.new(
    email:,
    url:,
    auth_token:,
    refresh_token:,
    csrf_token:,
  ))
}

/// An effect that tries to log in with the credentials from the form
pub fn login_effect(
  url,
  email,
  password,
  msg: fn(Result(Credentials, rsvp.Error)) -> msg_type,
) -> Effect(msg_type) {
  let req =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])
  let handler = rsvp.expect_json(decode_login(url, email), msg)
  rsvp.post(url <> "/api/auth/v1/login", req, handler)
}

pub fn test_credentials(
  cred: Credentials,
  msg: fn(Result(Credentials, rsvp.Error)) -> msg,
) -> Effect(msg) {
  let handler = rsvp.expect_json(decode_login(cred.url, cred.email), msg)
  rsvp.send(
    request.new()
      |> request.set_host(cred.url)
      |> request.set_path("/api/auth/v1/status")
      |> credentials.set_auth_headers(cred),
    handler,
  )
}
