# Python Project Rules

- Organize code under `src/` and tests under `test/`.
- Mirror the `src/` structure in `test/`; test files must be prefixed with `test_`.
- Use `pytest`.
- Tests should cover full-system execution and module-level behavior.
- Add unit tests only when a unit is sufficiently complex to justify isolated testing.
- Always use `.pyi` files for all Python code except tests.
- Every directory should include a terse `.md` file describing its purpose and relation to submodules.
- Before exploring changes, tag current git state and create a new branch.
- Delete tags from previous dates when they are no longer relevant.
- Write in a Pythonic style, with a slight functional preference when it does not hurt performance or idiomatic clarity.
