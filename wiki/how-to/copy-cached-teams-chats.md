# How to copy cached Teams chats to the clipboard

<img src="../assets/logo-senv-aliases-transparent.png" alt="" height="90" align="right">

Goal: copy one day of locally cached Microsoft Teams messages to the Windows
clipboard without creating a transcript file.

The reader can only export messages already present in the local Teams cache.
Open a conversation and scroll far enough for Teams to fetch older messages
before extracting a day that is no longer recent.

## 📋 Steps

1. Activate an updated senv session. Confirm that the command and shortcuts are
   loaded:

   ```bat
   alias tc.bat
   ```

   The result includes `tc`, `tct`, and `tcy`.

2. If automatic cache detection does not match the local Teams profile, set the
   private path in `custom\senv.custom.bat`:

   ```bat
   set "TEAM_CHAT_DB_PATH=<Teams IndexedDB LevelDB directory>"
   ```

   Keep a machine- or company-specific path in `custom`, not in the public
   scripts. Run `senv` again after changing the variable.

3. Choose a day:

   ```bat
   tc today
   tc yesterday
   tc 2026-07-10
   ```

   The daily shortcuts are:

   ```bat
   tct
   tcy
   ```

   Running `tc` without a day prints these choices. On the first extraction,
   or after its Go sources change, the launcher builds the cache reader and
   deploys it as `%HOME%\bin\teams-reader.exe`.

4. Paste the clipboard contents into the target application. The transcript is
   grouped by conversation and ordered by message time. Message line breaks are
   retained, non-breaking spaces become regular spaces, and Windows CRLF line
   endings are used.

## ✅ Check

From PowerShell, inspect the clipboard without creating a file:

```powershell
Get-Clipboard -Raw
```

The first line starts with `# Teams cached messages` and names the selected
date. No `teams-chat-*.txt` file is created.

## 🛠️ Troubleshooting

- **`Teams store not found`**: open Teams once, then set
  `TEAM_CHAT_DB_PATH` if the application uses another WebView profile.
- **An older conversation is absent**: open it in Teams and scroll until the
  requested messages are visible, then run `tc` again.
- **The reader needs rebuilding but Go is missing**: activate senv with Go on
  `PATH`, then rerun the command.
- **The aliases are absent after an update**: run the usual senv setup/update,
  then reload the session or run `aliasr`.

Related: [command reference](../reference/commands.md),
[environment variables](../reference/environment-variables.md),
[public engine and private data](../explanation/public-engine-private-data.md).
