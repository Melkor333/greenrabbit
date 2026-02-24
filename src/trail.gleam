import credentials.{type Credentials}
import formal/form.{type Form}
import gleam/dynamic/decode
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import login.{type LoginData, type LoginForm}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

/// The different states for accessing fields of trail
pub type State {
  LoggedIn(Credentials)
  LoggedOut(LoginForm)
}

/// Messages sent from effects produced by trail.update and handled by trail.update
pub type Msg {
  UserPressedLogin(Result(LoginData, Form(LoginData)))
  LoginRequestReturned(Result(Credentials, rsvp.Error))
  CredentialsTested(Result(Credentials, rsvp.Error))
  TrailReturnedRecord(table: String, data: Result(Record, rsvp.Error))
  TrailReturnedRecords(table: String, data: Result(List(Record), rsvp.Error))
  // TODO: UserLoggedOut
}

// TODO: Is this actually required? They
// map mostly 1by1 between trail & gleam except for the `Any` type
// TODO: fix the empty ones!
pub type Field {
  Real
  Int(Int)
  Text(String)
  Blob
  // TODO: does this decoder make any sense??
  Any(fn(Field) -> Field)
}

pub type Record {
  Record(List(Field))
}

pub type TableRequest {
  TableRequest(url: String, table: String, decoder: decode.Decoder(Record))
}

/// The ways records of the Trail DB can be accessed.
/// This is used in conjunction with `access_field` and TODO: `FieldTypes`
/// To interact with a table in different ways
pub type TableRequestType {
  Create(data: json.Json)
  Read(id: String)
  List(limit: Int, head: Option(String))
  Update(id: String, data: json.Json)
  Delete(id: String)
}

// TODO: Add a onSuccess return value?
/// The updateloop from trail 
pub fn update(state: State, msg: Msg) -> #(State, Effect(Msg)) {
  case state, msg {
    //Trying to log in
    LoggedOut(form), UserPressedLogin(Ok(login.LoginData(mail, password), ..)) -> #(
      LoggedOut(login.LoginForm(..form, active: False, errors: [])),
      login.login_effect(form.url, mail, password, LoginRequestReturned),
    )
    LoggedOut(login_form), UserPressedLogin(Error(login_data)) -> #(
      LoggedOut(login.LoginForm(
        form: login_data,
        active: True,
        url: login_form.url,
        errors: login_form.errors,
      )),
      effect.none(),
    )
    LoggedIn(..), UserPressedLogin(..) -> {
      echo "already logged in!"
      #(state, effect.none())
    }

    // Login request returned
    // TODO: return effect to validate credentials
    state, LoginRequestReturned(Ok(cred)) -> #(
      state,
      login.test_credentials(cred, CredentialsTested),
    )
    LoggedOut(login_form), LoginRequestReturned(Error(e))
    | LoggedOut(login_form), CredentialsTested(Error(e))
    -> {
      #(
        LoggedOut(
          login.LoginForm(..login_form, active: True, errors: [
            e,
            ..login_form.errors
          ]),
        ),
        effect.none(),
      )
    }
    LoggedIn(_), LoginRequestReturned(Error(_)) -> {
      echo "WTF?!"
      #(state, effect.none())
    }
    _, CredentialsTested(Ok(cred)) -> #(LoggedIn(cred), effect.none())
    // While logged in, testing the credentials failed -> we must log in again!
    // TODO: pass cred.email to login.new
    LoggedIn(cred), CredentialsTested(Error(_)) -> #(
      LoggedOut(login.new(cred.url)),
      effect.none(),
    )
    // Validation of login request
    _, TrailReturnedRecord(..) -> todo
    _, TrailReturnedRecords(..) -> todo
  }
}

pub fn init(url: String) -> #(State, Effect(Msg)) {
  let form = login.new(url)
  case credentials.get_browser_local() {
    Ok(cred) -> {
      #(
        LoggedOut(login.LoginForm(..form, active: False)),
        login.test_credentials(cred, CredentialsTested),
      )
    }
    Error(_) -> #(LoggedOut(form), effect.none())
  }
}

/// render a simple HTML Login Form
pub fn form_view(s: LoginForm) -> Element(Msg) {
  let form = s.form
  let handle_submit = fn(val) {
    form |> form.add_values(val) |> form.run() |> UserPressedLogin
  }

  html.form([event.on_submit(handle_submit)], [
    html.h1([], [html.text("Login")]),
    input_field(
      errors: form.field_error_messages(form, "mail"),
      is: "text",
      name: "mail",
      label: "Mail address",
      readonly: !s.active,
    ),
    input_field(
      errors: form.field_error_messages(form, "password"),
      is: "password",
      name: "password",
      label: "Password",
      readonly: !s.active,
    ),
    html.div([], [html.button([], [html.text("Login")])]),
    ..list.map(s.errors, fn(text: _type) {
      html.p([], [html.text(rsvp_to_string(text))])
    })
  ])
}

/// Translates various "rsvp.Error" messages to a string usable in HTML
fn rsvp_to_string(e: rsvp.Error) {
  case e {
    rsvp.BadBody(..) -> "Response was not valid!?"
    rsvp.BadUrl(s) -> "bad url: " <> s
    rsvp.HttpError(r) ->
      case r.status {
        401 -> "Wrong username or password"
        _ -> "Bad response(" <> int.to_string(r.status) <> "): " <> r.body
      }
    rsvp.JsonError(..) -> "Bad Json response!"
    rsvp.NetworkError -> "Network issue"
    rsvp.UnhandledResponse(..) -> "Return value wasn't json!"
  }
}

/// Render a single inputfield for the HTML form, including errors
fn input_field(
  errors errors,
  is type_: String,
  name name: String,
  label label: String,
  readonly readonly: Bool,
) {
  html.div([], [
    html.label([attribute.for(name)], [html.text(label), html.text(": ")]),
    html.input([
      attribute.type_(type_),
      attribute.id(name),
      attribute.name(name),
      attribute.readonly(readonly),
    ]),
    ..list.map(errors, fn(s) { html.p([], [html.text(s)]) })
  ])
}

/// Request field infos, but only once logged in
pub fn authenticated_field_api(
  endpoint endpoint: fn(Option(Credentials), TableRequest) -> Effect(Msg),
  state state: State,
  req req: TableRequest,
) -> Effect(Msg) {
  case state {
    LoggedIn(cred) -> endpoint(Some(cred), req)
    // TODO: check if login required
    LoggedOut(_) -> endpoint(None, req)
  }
}

/// fetch a single field
pub fn get(
  cred: Option(Credentials),
  req: TableRequest,
  record: String,
) -> Effect(Msg) {
  // TODO: Add to a queue?
  let handler =
    rsvp.expect_json(req.decoder, TrailReturnedRecord(table: req.table, data: _))
  // TODO: should use an `url`?
  rsvp.send(
    request.new()
      |> request.set_host(req.url)
      |> request.set_path("/api/records/v1/" <> req.table <> "/" <> record)
      |> fn(req) {
        case cred {
          Some(c) -> credentials.set_auth_headers(req, c)
          _ -> req
        }
      },
    handler,
  )
}

// TODO: optional limit?
/// List all records
pub fn list(cred: Option(Credentials), req: TableRequest) -> Effect(Msg) {
  let decoder = decode.list(req.decoder)
  let handler =
    rsvp.expect_json(decoder, TrailReturnedRecords(table: req.table, data: _))
  // TODO: should use an `url`?
  rsvp.send(
    request.new()
      |> request.set_host(req.url)
      |> request.set_path("/api/records/v1/" <> req.table)
      |> fn(req) {
        case cred {
          Some(c) -> credentials.set_auth_headers(req, c)
          _ -> req
        }
      },
    handler,
  )
}
