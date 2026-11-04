# Security Policy

Possum installs a privileged helper that runs as root, so security reports are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private vulnerability reporting instead:
**Security → Report a vulnerability** on this repository.

You can expect an acknowledgement within a few days.

## Design notes

- The helper exposes a single XPC method that takes a boolean. It maps that to one of two
  fixed invocations, `/usr/bin/pmset disablesleep 1` or `0`. No client-supplied strings reach
  a shell or `pmset`.
- In signed release builds, the helper accepts only connections from the Possum app signed by
  the same Apple Developer team. The app accepts only a helper signed by that team too. Both use
  `NSXPCConnection.setCodeSigningRequirement`.
- Local ad-hoc builds have no team identity, so they fall back to matching the bundle identifier.
  Don't use ad-hoc builds as your daily driver.
- No signing keys, certificates or API keys are stored in this repository. CI reads them from
  GitHub environment secrets and deletes them after each run.
