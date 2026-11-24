# Repository Guidelines

## Project Structure & Module Organization

This workspace is currently empty. No source tree, tests, assets, or project configuration has been committed. Keep this guide updated as the project takes shape.

When adding the initial implementation, group application code by feature and keep shared utilities separate. Place tests in dedicated test targets or directories, and keep images and other resources in an explicit asset directory. Document the actual paths here once established; do not assume a particular framework from the repository name.

## Build, Test, and Development Commands

No build, test, or local run commands are currently configured. Before introducing application code, add a README with prerequisites, supported toolchain versions, and reproducible setup instructions.

Document exact commands for building, running, and testing when those workflows exist. If an Xcode project is introduced, include its project or workspace name, shared scheme, and simulator destination in command examples. Avoid documenting commands that have not been verified.

## Coding Style & Naming Conventions

No formatter, linter, or language-specific style is configured yet. Use consistent indentation within each file and descriptive names that follow the selected language's conventions. Keep files focused on one responsibility. When adopting formatting or linting tools, commit their configuration and document how to run them.

## Testing Guidelines

No testing framework or coverage threshold exists. Add tests alongside new behavior using the framework appropriate to the chosen stack. Name tests after observable behavior, cover failure paths, and keep fixtures deterministic. Record test commands and any required environment setup in the README.

## Commit & Pull Request Guidelines

No Git history is available to establish existing conventions. Use concise, imperative commit subjects, such as `Add photo import validation`, and keep commits focused.

Pull requests should describe the change, link relevant issues, and report validation performed. Include screenshots for visible interface changes and identify any untested behavior.

## Security & Configuration

Never commit credentials, signing keys, personal photos, or local configuration containing secrets. Add appropriate ignore rules before introducing generated files or machine-specific settings.
