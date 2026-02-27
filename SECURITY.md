# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in HomeKit Control, please report it responsibly.

**DO NOT open a public GitHub issue for security vulnerabilities.**

Instead, please use one of these methods:

1. **GitHub Security Advisories** (Preferred): Use the "Report a vulnerability" button on the [Security tab](https://github.com/kochj23/HomekitControl/security/advisories/new)
2. **Email**: Contact the maintainer through their [GitHub profile](https://github.com/kochj23)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Fix Timeline**: Depends on severity
  - Critical: Within 24 hours
  - High: Within 1 week
  - Medium: Within 2 weeks
  - Low: Next release cycle

## Security Features

This project follows security best practices:
- No hardcoded credentials (all secrets via macOS Keychain)
- Input validation and sanitization
- Dependency scanning via Dependabot
- Secret scanning enabled on the repository
- Branch protection on the default branch

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

## License

This project is licensed under the MIT License. Security researchers are welcome to test this software in accordance with responsible disclosure practices.
