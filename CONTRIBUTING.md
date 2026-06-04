# Contributing to Purple Safety

Thanks for your interest in contributing! This document explains how to get the project running locally, the preferred workflow, and guidelines for submitting changes.

## Code of Conduct

Please follow a respectful and collaborative tone in issues and pull requests. If you'd like, add a `CODE_OF_CONDUCT.md` to formalize this project.

## Development Setup

1. Fork the repo and clone your fork.
2. Install Flutter and platform toolchains.

```bash
git clone <your-fork-url>
cd purple-safety
flutter pub get
```

3. Add Firebase config files as described in the project `readme.md`.

## Branching & Workflow

- Use feature branches: `feature/short-description` or `fix/brief-description`.
- Keep PRs small and focused. Rebase when appropriate.

## Coding Standards

- Follow Dart/Flutter best practices and the project's existing style.
- Run the formatter before committing:

```bash
dart format .
```

## Testing

- Add unit and widget tests where appropriate.
- Run the test suite locally:

```bash
flutter test
```

## Pull Requests

- Target the `main` branch (or whichever is the default branch).
- Include a clear description of what the PR changes and why.
- Link related issues and include testing steps.

## Security & Secrets

- Do NOT commit secrets or keys (API keys, Firebase service account files, etc.).
- Use environment variables or secure secret management for CI.

## License

Contributions are accepted under the project's license. If no `LICENSE` file exists, discuss licensing with maintainers before contributing.

## Need Help?

Open an issue describing the problem or feature you'd like to work on — maintainers will try to respond.
