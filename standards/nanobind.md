@cpp.md
@python.md

## nanobind Bindings

- Place bindings in `bindings/`, separate from core C++ logic. One file per module: `bind_<module>.cpp`.
- C++ `camelCase` methods → Python `snake_case` via nanobind. Use `nb::arg("name")` for Python-friendly parameter names.

## Ownership and Lifetime

- Default: nanobind manages ownership. Use `nb::rv_policy::reference` only when C++ retains ownership and guarantees the object outlives Python references.
- Never return raw pointers without explicit lifetime annotation.
- Prefer returning by value or `std::shared_ptr`. Document ownership on each binding that transfers or shares it.

## Type Conversions

- Use automatic conversions for standard types (`std::string` ↔ `str`, `std::vector` ↔ `list`).
- Use `nb::ndarray` for NumPy interop — specify dtype and shape constraints.

## Testing

- Test bindings from Python using pytest, not from C++. The binding is an implementation detail.
- Ensure round-trip tests: create in Python → pass to C++ → get result back.
