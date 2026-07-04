# How to work behind a corporate proxy

Goal: give every senv session (curl, git, package managers) internet access
through an authenticating corporate proxy, without storing credentials.

senv uses [px](https://github.com/genotrance/px), a local proxy that handles
the corporate authentication (NTLM/Kerberos) and listens on `127.0.0.1`.
Sessions then point at that local port.

## Steps

1. Add `px` to the profile application list (`custom\install_<profile>.list`):

   ```text
   px-* pxs
   ```

2. Configure the upstream in `custom\px.ini` (placeholders — use your real
   corporate values in the private repository only):

   ```ini
   [proxy]
   server = proxy.example.corp:8080
   port = 3128
   listen = 127.0.0.1
   ```

3. Point the sessions at the local proxy in `custom\senv.custom.bat`:

   ```bat
   set "HTTP_PROXY=http://127.0.0.1:3128"
   set "HTTPS_PROXY=http://127.0.0.1:3128"
   set "NO_PROXY=localhost,127.0.0.1,.example.corp"
   ```

   `setup.bat` treats a missing `HTTP_PROXY`/`HTTPS_PROXY` in that file as a
   fatal error once `senv.custom.bat` exists.

4. Start it: the install hook `custom\pxs.post.bat` copies `px.ini` into
   `%HOME%` and launches px. After that, each session inherits the proxy
   variables from `senv.custom.bat`.

## Daily use

- `ti` (testinternet) — checks connectivity with the portable `curl` against
  a rotating test URL,
- `ei` (ensure_internet) — runs `ti`; when offline and `HTTPS_PROXY` is set,
  it restarts the local proxy (`pxkill.bat` then `px.bat`, both shipped in
  senv `bin\` and copied to `%HOME%\bin` at setup) and re-tests.

Scripts that need the network (`dwl`, `gsh`) call `ei` themselves.

## Check

`ti` reports success, and `curl -I https://github.com` answers from a senv
session while the proxy variables are set.

Related: [commands](../reference/commands.md),
[custom repository](../../custom_example/README.md).
