@common.md

## Python

- Style: enforced by `ruff` (format + lint) and `mypy --strict`, configured in `pyproject.toml`.
- All functions must have full type annotations (mypy strict mode).
- Use built-in generics (`list[int]`, `dict[str, Any]`) and `|` union syntax.

## Testing (pytest)

- Test files: `test_<module>.py` in `tests/`.
- Name tests descriptively: `test_solver_returns_optimal_for_feasible_input`.
- Use `conftest.py` for shared fixtures, `pytest.mark.parametrize` for data-driven tests.
- Terse output: `pyproject.toml` bakes in quiet defaults for pytest (`addopts`), mypy (`pretty = false`), and ruff (`output-format = "concise"`). Override per-invocation (`pytest -v`, `mypy --pretty`) when debugging; don't edit the defaults.

## Dependencies

- Pin with `>=` lower bounds in `pyproject.toml`. Use `uv` or `pip`.

## LSP

Install `pyright-lsp@claude-plugins-official`. Pyright reads `[tool.mypy]` and project layout from `pyproject.toml` — no extra config needed. Prefer `LSP` tool queries (`goToDefinition`, `hover`, `documentSymbol`, `workspaceSymbol`) over `Read` for symbol questions.
