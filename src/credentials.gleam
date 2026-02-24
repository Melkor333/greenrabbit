import gleam/http/request
import gleam/json
import gleam/result
import plinth/javascript/storage

pub type Credentials {
  Credentials(
    url: String,
    email: String,
    auth_token: String,
    refresh_token: String,
    csrf_token: String,
  )
}

pub fn new(
  email email,
  url url,
  auth_token auth_token,
  refresh_token refresh_token,
  csrf_token csrf_token,
) -> Credentials {
  let c = Credentials(email:, url:, auth_token:, refresh_token:, csrf_token:)
  // TODO: check if even in a browser?
  let _ =
    set_browser_local(c)
    |> result.lazy_or(fn() {
      echo "Couldn't write credentials to browser local store!"
      Ok(Nil)
    })
  c
}

fn set_browser_local(l: Credentials) -> Result(Nil, Nil) {
  use store <- result.try(storage.local())
  use _ <- result.try(storage.set_item(store, "trailbase_url", l.url))
  use _ <- result.try(storage.set_item(store, "trailbase_email", l.email))
  use _ <- result.try(storage.set_item(
    store,
    "trailbase_auth_token",
    l.auth_token,
  ))
  use _ <- result.try(storage.set_item(
    store,
    "trailbase_refresh_token",
    l.refresh_token,
  ))
  use _ <- result.try(storage.set_item(
    store,
    "trailbase_csrf_token",
    l.csrf_token,
  ))
  Ok(Nil)
}

// TODO: reuse from admin page?
pub fn get_browser_local() -> Result(Credentials, Nil) {
  use store <- result.try(storage.local())
  use url <- result.try(storage.get_item(store, "trailbase_url"))
  use email <- result.try(storage.get_item(store, "trailbase_email"))
  use auth_token <- result.try(storage.get_item(store, "trailbase_auth_token"))
  use refresh_token <- result.try(storage.get_item(
    store,
    "trailbase_refresh_token",
  ))
  use csrf_token <- result.try(storage.get_item(store, "trailbase_csrf_token"))
  Ok(new(email:, url:, auth_token:, refresh_token:, csrf_token:))
}

pub fn set_auth_headers(
  req: request.Request(body),
  cred: Credentials,
) -> request.Request(body) {
  req
  |> request.set_header("Authorozation", "bearer " <> cred.auth_token)
  |> request.set_header("CSRF-Token", cred.csrf_token)
  |> request.set_header("Refresh-Token", cred.refresh_token)
}
