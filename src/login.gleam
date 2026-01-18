import formal/form.{type Form}
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type LoginForm {
  LoginForm(form: Form(LoginData), active: Bool, url: String)
}

pub type Credentials {
  Credentials(
    form: Form(LoginData),
    mail: String,
    auth_token: String,
    refresh_token: String,
    csrf_token: String,
  )
}

pub type LoginFailure {
  BadCredentials
  Timeout
}

pub type LoginMsg {
  UserPressedLogin(Result(LoginData, Form(LoginData)))
  LoginRequestReturned(Result(Credentials, LoginFailure))
  // TODO: UserLoggedOut
}

// TODO: Add a onSuccess return value?
pub fn update(m: LoginForm, msg: LoginMsg) -> #(LoginForm, Effect(LoginMsg)) {
  case msg {
    // Lock form
    UserPressedLogin(Ok(LoginData(mail, password), ..)) -> #(
      LoginForm(..m, active: False),
      effect.none(),
      //login_effect(mail, password),
    )
    UserPressedLogin(Error(_)) -> #(LoginForm(..m, active: True), effect.none())
    //UserPressedSignup -> #(m, login(msg.mail, msg.password))
    LoginRequestReturned(Ok(_)) -> #(m, todo)
    _ -> #(m, todo)
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
pub fn view(m: LoginForm) -> Element(LoginMsg) {
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
    ),
    input_field(
      errors: form.field_error_messages(form, "password"),
      is: "password",
      name: "password",
      label: "Password",
    ),
    html.div([], [html.button([], [html.text("Login")])]),
  ])
}

fn input_field(
  errors errors,
  is type_: String,
  name name: String,
  label label: String,
) {
  html.div([], [
    html.label([attribute.for(name)], [html.text(label), html.text(": ")]),
    html.input([
      attribute.type_(type_),
      attribute.id(name),
      attribute.name(name),
    ]),
    ..list.map(errors, fn(s) { html.p([], [html.text(s)]) })
  ])
}
