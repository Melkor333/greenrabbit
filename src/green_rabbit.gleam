import login
import lustre
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  //Model(
  //  credentials: login.Credentials,
  //  auth_token: String,
  //  refresh_token: String,
  //  csrf_token: String,
  //)
  Login(login.Login)
}

type Msg {
  LoginMsg(login.LoginMsg)
  //UserPressedLogin(Result(login.LoginData, Form(login.LoginData)))
  //  UserPressedSignup(mail: String, password: String)
  //UserLoggedIn
}

fn update(m: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    // transition to logged-in page!
    LoginMsg(login_msg) -> {
      let Login(form) = m
      let #(form, effect) = login.update(form, login_msg)
      #(Login(form), effect.map(effect, fn(m) { LoginMsg(m) }))
    }
    _ -> todo
  }
}

fn init(_args) {
  #(
    Login(
      login.LoginForm(login.login_form(), True, "http://localhost:4000", []),
    ),
    effect.none(),
  )
}

fn view(m) {
  html.div([], [
    case m {
      Login(login.Credentials(..)) -> html.text("Logged in!")
      Login(form) -> element.map(login.view(form), fn(e) { LoginMsg(e) })
    },
  ])
}
