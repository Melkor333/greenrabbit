import formal/form.{type Form}
import gleam/dynamic/decode
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

pub type Login {
  LoginForm(
    form: Form(LoginData),
    active: Bool,
    url: String,
    errors: List(rsvp.Error),
  )
  Credentials(
    url: String,
    email: String,
    auth_token: String,
    refresh_token: String,
    csrf_token: String,
  )
}

pub type LoginMsg {
  UserPressedLogin(Result(LoginData, Form(LoginData)))
  LoginRequestReturned(Result(Login, rsvp.Error))
  // TODO: UserLoggedOut
}

// TODO: Add a onSuccess return value?
pub fn update(m: Login, msg: LoginMsg) -> #(Login, Effect(LoginMsg)) {
  case msg {
    // Lock form
    UserPressedLogin(Ok(LoginData(mail, password), ..)) ->
      case m {
        LoginForm(..) -> #(
          LoginForm(..m, active: False),
          login_effect(m.url, mail, password),
        )
        Credentials(..) -> {
          echo "already logged in!"
          #(m, effect.none())
        }
      }
    UserPressedLogin(Error(form)) -> {
      // TODO: do nothing if `Credential'?`
      let assert LoginForm(..) = m
      #(
        LoginForm(form:, active: True, url: m.url, errors: m.errors),
        effect.none(),
      )
    }
    //UserPressedSignup -> #(m, login(msg.mail, msg.password))
    LoginRequestReturned(Ok(cred)) -> #(cred, effect.none())
    LoginRequestReturned(Error(e)) -> {
      let assert LoginForm(..) = m
      #(LoginForm(..m, active: True, errors: [e, ..m.errors]), effect.none())
    }
  }
}

pub type LoginData {
  LoginData(mail: String, password: String)
}

pub fn login_form() -> Form(LoginData) {
  form.new({
    use mail <- form.field("mail", form.parse_email)
    // TODO: min 8, etc.
    use password <- form.field(
      "password",
      form.parse_string
        |> form.check_not_empty,
    )

    form.success(LoginData(mail:, password:))
  })
}

// show the form
pub fn view(m: Login) -> Element(LoginMsg) {
  case m {
    LoginForm(..) -> {
      let form = m.form
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
          readonly: !m.active,
        ),
        input_field(
          errors: form.field_error_messages(form, "password"),
          is: "password",
          name: "password",
          label: "Password",
          readonly: !m.active,
        ),
        html.div([], [html.button([], [html.text("Login")])]),
        ..list.map(m.errors, fn(s: _type) {
          html.p([], [html.text(rsvp_to_string(s))])
        })
      ])
    }
    Credentials(..) -> element.none()
  }
}

fn rsvp_to_string(e: rsvp.Error) {
  case e {
    rsvp.BadBody(..) -> "Response was not valid!?"
    rsvp.BadUrl(s) -> "bad url: " <> s
    rsvp.HttpError(r) ->
      "Bad response(" <> int.to_string(r.status) <> "): " <> r.body
    rsvp.JsonError(..) -> "Bad Json response!"
    rsvp.NetworkError -> "Network issue"
    rsvp.UnhandledResponse(..) -> "Return value wasn't json!"
  }
}

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

fn login_effect(url, email, password) {
  let req =
    json.object([
      #("email", json.string(email)),
      #("password", json.string(password)),
    ])
  let handler = rsvp.expect_json(decode_login(url, email), LoginRequestReturned)
  rsvp.post(url <> "/api/auth/v1/login", req, handler)
}

fn decode_login(url, email) {
  use auth_token <- decode.field("auth_token", decode.string)
  use refresh_token <- decode.field("refresh_token", decode.string)
  use csrf_token <- decode.field("csrf_token", decode.string)
  decode.success(Credentials(
    email:,
    url:,
    auth_token:,
    refresh_token:,
    csrf_token:,
  ))
}
