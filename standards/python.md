@common.md

## Python

- Style: enforced by `ruff` (format + lint) and `mypy --strict`, configured in `pyproject.toml`. Hooks auto-format on save — don't fix formatting manually.
- All functions must have full type annotations (mypy strict mode).
- Use built-in generics (`list[int]`, `dict[str, Any]`) and `|` union syntax.

## Testing (pytest)

- Test files: `test_<module>.py` in `tests/`.
- Name tests descriptively: `test_solver_returns_optimal_for_feasible_input`.
- Use `conftest.py` for shared fixtures, `pytest.mark.parametrize` for data-driven tests.

## Dependencies

- Pin with `>=` lower bounds in `pyproject.toml`. Use `uv` or `pip`.
