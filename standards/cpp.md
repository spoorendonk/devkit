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
- Terse output: `GTEST_BRIEF=1` prints only failures, `ctest --progress` collapses the running list, `CMAKE_INSTALL_MESSAGE=LAZY` suppresses install chatter. Don't remove these.

## LSP

Install `clangd-lsp@claude-plugins-official` plus `clangd` itself (`apt install clangd` or from LLVM). Devkit ships `.clangd` pointing at `build/compile_commands.json` (produced by `CMAKE_EXPORT_COMPILE_COMMANDS ON`). Prefer `LSP` tool queries (`goToDefinition`, `hover`, `documentSymbol`) over `Read` for symbol questions.
