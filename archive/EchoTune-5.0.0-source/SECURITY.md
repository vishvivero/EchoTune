# Security Policy

## Reporting a vulnerability

If you find a security issue in EchoTune, please report it privately rather
than opening a public issue.

- Email: **security@echotune.app**
- Please include steps to reproduce and the version affected.

We aim to acknowledge reports within a few business days and to ship a fix as
quickly as the severity warrants. Responsible disclosure is appreciated; we're
happy to credit reporters who want it.

## Scope

In scope:
- The EchoTune macOS application in this repository.
- License activation and referral flows.

Out of scope:
- Third-party dependencies (report those upstream).
- Social-engineering or physical-access attacks.

## Handling of your data

EchoTune processes audio locally by default. Cloud transcription and AI cleanup
only run with an API key you supply, and send data to the provider you chose.
Crash reporting is opt-in and carries no personally identifying information.
