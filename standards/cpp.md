@common.md

## C++

- Target C++23. Use modern features (`std::expected`, concepts, ranges, `constexpr`).
- Style: Google-based, enforced by `.clang-format` and `.clang-tidy`.
- Use `#pragma once` for include guards.
- Minimize includes in headers. Forward-declare where possible.

## CMake

- `set(CMAKE_EXPORT_COMPILE_COMMANDS ON)` for clang-tidy.
- Use FetchContent for dependencies.
- One `CMakeLists.txt` per directory with source files.

## Testing (GoogleTest)

- Test files: `<module>_test.cpp` in `tests/`.
- Name tests descriptively: `TEST_F(SolverTest, ReturnsOptimalForFeasibleInput)`.
