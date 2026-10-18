# Flutter <-> native channel contract

Bridges live in `:app` (`bridge/SessionBridge.kt`, `bridge/WidgetBridge.kt`) and delegate to
`TududiCore` from `:tududi_core`. Dart side: `lib/core/platform/{session_bridge,widget_bridge}.dart`.
Native work runs on the IO dispatcher; replies are posted on the main thread.

All argument maps use the keys below; absent optional keys are `null`. Errors are reported as
`PlatformException` with the codes listed per channel.

## MethodChannel `tududa/session`

| Method | Arguments | Result |
| --- | --- | --- |
| `provision` | `{serverUrl: String, allowInsecureHttp: bool, email: String, password: String, accountUid: String}` | `null` |
| `clear` | `{}` | `null` |
| `getCredentials` | `{}` | `{serverUrl: String, email: String, password: String}` or `null` when not provisioned |
| `readCookies` | `{host: String}` | `List<String>` (cookie header strings as stored; empty list if none) |
| `writeCookies` | `{host: String, cookies: List<String>}` | `null` (empty list removes the host) |
| `state` | `{}` | `{provisioned: bool, serverUrl: String, accountUid: String, loginFailed: bool}` |

Semantics:

- `provision` stores the credentials in the encrypted vault. If `accountUid` or `serverUrl`
  differs from the stored values, the native session cookies, board cache, change log and login
  flags/backoff are reset. It always re-enables silent login (`loginFailed` becomes false).
  Error `INVALID_ARGUMENT`: unparsable URL, or `http://` with `allowInsecureHttp == false`.
- `clear` does a best-effort `GET /api/logout` with the native cookie (5 s cap), then wipes the
  whole vault (credentials, both cookie sets, board cache, change log).
- `getCredentials` is for the Dart re-login path; the password never goes anywhere else.
- `readCookies` / `writeCookies` hold the Dart HTTP client's cookies per host (replaces the old
  `appDocs/.cookies/` folder).
- `loginFailed` is true when silent login was disabled after the server rejected the credentials.

## MethodChannel `tududa/widget`

| Method | Arguments | Result |
| --- | --- | --- |
| `refresh` | `{}` | `null`. Re-renders all home-screen widgets (and refetches the board in the background). |
| `overlay` | `{uid: String, status: int}` | `null`. Shows a locally made, not yet synced status change on the widget only. `status` is the numeric task status (0 not started, 2 done, ...). |
| `pendingChanges` | `{sinceSeq: int}` | `List<{seq: int, uid: String, status: int, atMillis: int}>` ordered by `seq`, entries with `seq > sinceSeq` |
| `ack` | `{seq: int}` | `null`. Deletes log entries with `seq <= seq`. |

Semantics:

- The change log only contains changes the **server confirmed** (successful PATCH made by the
  widget). Sequence numbers are strictly increasing and survive `ack`; they restart at 1 only
  after `clear` or an account/server change in `provision`.
- Dart applies the entries through its merge rules, refetches those tasks, then calls `ack`.

## EventChannel `tududa/widget/events`

Emits an `int`: the latest change sequence number. Emitted once on listen (current value) and
again whenever a widget change is logged. Dart reacts by calling `pendingChanges`.
