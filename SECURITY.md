# Security Policy

## About This Project

Dungeon Master Tool is an open-source, offline-first desktop and mobile application. It does not operate a web service, API, or server. All user data is stored locally on the device in a SQLite database.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 2.0.x   | Yes       |
| < 2.0   | No        |

The project is currently in beta. Security fixes are applied to the latest release only.

## Reporting a Vulnerability

If you discover a security issue (for example, a path traversal in file import, unsafe deserialization, or a dependency with a known CVE), please report it privately:

- **Email:** orhunerenyalcinkaya@gmail.com
- **Subject line:** [SECURITY] Dungeon Master Tool

Please include:

- A description of the vulnerability.
- Steps to reproduce, if applicable.
- The version and platform you tested on.

You can expect an initial response within 7 days. Please do not open a public GitHub issue for security vulnerabilities.

## Scope

**In scope:**

- The Flutter application code in this repository.
- Third-party dependencies used by the application.
- Build and release pipeline (GitHub Actions).

**Out of scope:**

- The project website (static GitHub Pages site).
- Theoretical attacks requiring physical device access.
