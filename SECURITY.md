# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 2.x     | ✅ Active support |
| 1.x     | ❌ End of life |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

VaultX handles sensitive credential data. A public disclosure before a patch is available could put users at risk.

### How to report

Use [GitHub's private security advisory system](https://github.com/yourusername/vaultx/security/advisories/new).

Include:
- A description of the vulnerability
- Steps to reproduce it
- The potential impact
- Any suggested fixes (optional but appreciated)

### What to expect

- **Acknowledgement within 48 hours** of your report
- **Regular updates** on the investigation and fix timeline
- **Credit in the release notes** if you want it (you can also report anonymously)
- **No legal action** — we consider good-faith security research a service, not a threat

### Scope

The following are in scope:

- Encryption or key derivation weaknesses
- Data leakage (master password, vault contents leaving the device unexpectedly)
- Authentication bypass
- Biometric bypass
- Insecure data storage
- Cloud sync vulnerabilities that expose plaintext data

The following are out of scope:

- Issues requiring physical access to an already unlocked device
- Theoretical weaknesses with no practical exploit path
- Social engineering attacks on users
- Rate limiting on the HaveIBeenPwned API (not our infrastructure)

## Security Design Principles

VaultX is designed around the assumption that any component outside the user's device may be compromised:

1. **The server is untrusted** — Firebase stores only ciphertext. A complete Firebase breach exposes nothing readable.
2. **The developer is untrusted** — There is no mechanism for the developer to decrypt user data. Zero-knowledge is enforced by design, not policy.
3. **The source code is public** — Security does not depend on obscurity. The encryption is the security.
4. **The master password is the only secret** — Everything else — API keys, Firebase credentials, source code — can be exposed without compromising vault data.
