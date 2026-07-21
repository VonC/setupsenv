# How to manage Python virtual environments

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: pick a Python version for the current session and work in a virtual
environment, global or per-project.

## 📋 Steps

1. Select the Python version (and optionally the venv choice) in one call:

   ```cmd
   switchpy            :: interactive: version, then venv choice via gum
   switchpy 3.13       :: version cycle, then venv choice
   switchpy 3.13 local :: no prompt at all
   ```

   The second argument answers the venv question up front:

   - `no`: no venv, just `%PRGS%\pythons\python<version>` on the PATH,
   - `global`: venv under `%PYTHON_ROOT%\venvs` (shared location,
     `PYTHON_ROOT` being `%PRGS%\pythons`),
   - `local`: venv under `%CD%\venvs`, named
     `python_<version>_<project-folder>`.

   `switchpy` creates the venv with `python -m venv` when missing, repairs a
   partial venv without replacing an existing interpreter, fixes the
   `VIRTUAL_ENV` path inside its `activate.bat`, sets
   `PYTHON_HOME`/`PYTHON_VERSION`, and defines a `deactivate` doskey.

   For a local venv, it also prepares the project dependencies:

   - when one or more `requirements*.txt` files exist, each file is installed
     with `python -m pip install -r`;
   - otherwise, when `pyproject.toml` exists, uv is installed when missing and
     `uv sync --all-groups` is run (`--frozen` is added when `uv.lock` exists);
   - when neither form exists, dependency installation is skipped.

   Missing pip is restored with `ensurepip` before either dependency path.

2. Later, from a project that already has a `venvs\` folder, activate it
   without re-running `switchpy`:

   ```cmd
   activate
   ```

   `activate.bat` deactivates any current venv, then expects exactly one
   `venvs\python_*` folder and calls its `Scripts\activate.bat` (it stops
   with an error on zero or several candidates).

3. Leave the venv with `deactivate`.

## Per-project sessions

A project `senv.bat` can chain the global activation with
`switchpy 3.13 local`, so opening a session in the project lands directly in
the right interpreter and venv: see
[per-project senv](../explanation/anatomy-of-a-session.md).

## ✅ Check

`python --version` matches the selected version, and the prompt (or
`echo %VIRTUAL_ENV%`) shows the active venv path.

Related: [commands](../reference/commands.md),
[naming conventions](../reference/naming-conventions.md).
