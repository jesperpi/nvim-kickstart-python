# Python Project Rules

- Organize code under `src/` and tests under `test/`.
- Mirror the `src/` structure in `test/`; test files must be prefixed with `test_`.
- Use `pytest`.
- Tests should cover full-system execution and module-level behavior.
- Tests files should have minimal documentation explaining the functionality they are testing.
- Tests should test narrow things, better to split into more tests if they are too broad. Test names should be short but informative, do not duplicate information in docs.
- Add unit tests only when a unit is sufficiently complex to justify isolated testing.
- Always create `.pyi` files for all Python implementations except tests.
- Every src directory should include a terse `.md` file describing its purpose and relation to submodules.
- Before exploring changes, ensure git is committed and tag current git state with ai-timestamp-start and create a new branch. Changes should be made in small commits with clear messages. Before finishing refactor to clean up the commit history withour changing the state of the final version. Tag final version with ai-timestamp-end tag.
- Delete tags from previous dates when they are no longer relevant.
- Write in a Pythonic style, with a slight functional preference when it does not hurt performance or idiomatic clarity.
- Read *.pyi files in preference to the real files unless you need implementation details
