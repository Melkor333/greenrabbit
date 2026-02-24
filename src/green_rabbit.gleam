import credentials.{type Credentials}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import login
import lustre
import lustre/effect.{type Effect}
import lustre/element
import lustre/element/html
import trail

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Model(trail: trail.State, cookies: List(Cookies))
  //  csrf_token: String,
  //)
  //Login(login.Login)
}

type Msg {
  TrailMsg(trail.Msg)
  //CookieMsg(Cookies)
  //UserPressedLogin(Result(login.LoginData, Form(login.LoginData)))
  //  UserPressedSignup(mail: String, password: String)
  //UserLoggedIn
}

fn update(m: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    TrailMsg(trail.CredentialsTested(Ok(cred))) -> {
      let cookies =
        effect.map(
          trail.authenticated_field_api(
            endpoint: trail.list,
            state: m.trail,
            req: trail.TableRequest("cookies", decode_cookies()),
          ),
          TrailMsg,
        )
      #(Model(..m, trail: trail.LoggedIn(cred)), cookies)
    }
    TrailMsg(trail.TrailReturnedRecords(table: "cookies", data: Ok(records))) -> {
      let l =
        list.map(records, fn(in) {
          let trail.Record(c) = in
          // TODO: Wtf?!
          let assert [Ok(trail.Text(user)), Ok(trail.Int(cookies))] = [
            list.first(c),
            list.last(c),
          ]
          Cookies(user:, cookies:)
        })
      #(Model(..m, cookies: list.append(m.cookies, l)), effect.none())
    }
    // transition to logged-in page!
    TrailMsg(trail_msg) -> {
      //let Login(form) = m
      let #(state, effect) = trail.update(m.trail, trail_msg)
      #(Model(..m, trail: state), effect.map(effect, fn(m) { TrailMsg(m) }))
    }
  }
}

fn init(_args) {
  let #(state, e) = trail.init("http://localhost:4000")
  #(Model(cookies: [], trail: state), effect.map(e, TrailMsg))
}

fn view(m: Model) {
  html.div([], [
    case m.trail {
      trail.LoggedIn(..) -> html.text("Logged in!")
      trail.LoggedOut(form) ->
        element.map(trail.form_view(form), fn(e) { TrailMsg(e) })
    },
    //TODO: Map over cookies
    html.div(
      [],
      list.map(m.cookies, fn(c) {
        html.p([], [html.text(c.user <> ": " <> int.to_string(c.cookies))])
      }),
    ),
  ])
}

type Cookies {
  Cookies(user: String, cookies: Int)
}

fn decode_cookies() -> decode.Decoder(trail.Record) {
  use user <- decode.field("user", decode.string)
  use cookies <- decode.field("cookies", decode.int)
  decode.success(trail.Record([trail.Text(user), trail.Int(cookies)]))
}
