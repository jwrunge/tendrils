# Tendrils

## Declarative, cross-platform automation

## Basic functionality plan

### Goals for `tendrils init`
- Initialize Tendrils in the current folder (when invoked via `cargo tendrils init` or `npx tendrils`).
- Detect OS (macOS, Linux, Windows).
- Prompt to install foundational prerequisites (e.g., OpenSSH; Homebrew on macOS).
- Create a minimal project layout and configuration files needed for subsequent commands.
- Be safe-by-default (no root-level changes without explicit confirmation).

### CLI surface (v1)
- `tendrils init`
- `tendrils addkey`
- `tendrils harden`
- `tendrils revokekeys`
- `tendrils apply` (apply software declarations)

### Project layout (initialized in current folder)
- `tendrils.json` (project config, platform detection results)
- `hosts.json` (host groups)
- `profiles/` (setup profiles)
- `profiles/default/software_declarations.json`
- `profiles/default/scripts/` (optional scripts or hooks)

### Initialization flow (Unix-like first)
- Detect OS and package manager capabilities.
- Check for SSH tooling:
    - macOS: `ssh`, `ssh-keygen` (via system or Xcode CLT), optional Homebrew install.
    - Linux: `openssh-client` and `openssh-server` (distro-specific).
- Prompt to install missing prerequisites.
- Write initial config files and default profile.

### Windows (shim for now)
- Detect Windows and show a clear message that initialization is limited.
- Optionally check for OpenSSH client availability (PowerShell `Get-WindowsCapability`).
- Generate the same file layout, but defer package installs.

### Safety and permissions
- Run as current user by default.
- Escalate only when required, and only for specific commands.
- Document least-privilege approach for automation users.

### Next implementation steps
- Implement OS detection and prerequisite checks.
- Implement `tendrils init` with prompts and file generation.
- Implement `addkey` for local host as first target.
- Implement `apply` for `software_declarations.json` on macOS and Debian-based Linux.

### Setting up hosts

Declaratively define hosts in hosts.json.

```json
{
    "local": [ "localhost", "localhost:5173", "localhost:3000" ],
    "lamp-servers": [ "example.com" ],
    "node-servers": [ "example2.com" ]
}
```

### Setting up SSH key-pair-based access

Tendrils generates a key pair and pushes the public key to the target.

```bash
tendril addkey local FOR_USER=jwrunge AUTH_AS=jwrunge
```

Leaving out `FOR_USER` creates a user, "tendril," used for running automated tasks:

```bash
tendril addkey local AUTH_AS=jwrunge
```

When creating the "tendril" user, you will be asked to set a `sudo` password (or no password). For an automated user, it is common NOT to require a sudo password, and will result in less password prompting. If you want to avoid facing that question, run:

```bash
tendril addkey local AUTH_AS=jwrunge elevate=123456
```

OR 

```bash
tendril addkey local AUTH_AS=jwrunge elevate-auto
```

To set up a new computer using an existing computer's SSH key-based access, run:

```bash
tendril addkey local keypath=./my_pub_key
```

### Hardening your system

Once you have SSH key-based access on the computers you need access from, it is good practice to harden your system. Using a user with SSH key access, run:

```bash
tendril harden local AUTH_AS=jwrunge
```

This will remove SSH password-based login. Once you do this, it will be more difficult to access your server from random computers -- good for security, but make sure you have another way in if your only SSH-authenticated device dies. You can use `addkey \[group\] keypath` on an SSH-authenticated computer to set up a new computer's access.

### Revoking SSH keys

If something goes horribly wrong, you can revoke SSH keys (and optionally re-enable SSH password login) using:

```bash
tendril revokekeys local [AUTH_AS=jwrunge] [FOR_USER=myUser] [ENABLE_PWORD=true]
```

If you do not specify a user, all keys will be revoked. You will be prompted to ensure you want to do this.

### Declarative software assurances

Declare the software you want present on your system in `[your_setup_profile]/software_declarations.json`:

```json
{
    "software": {
        "git": "latest",
        "nginx": "latest",
        "mariadb": "latest",
        "php": { "version": "^8.2", "pruneOld": false }
    },
    "linux": {
        "debian": {
            "match": [{
                "cmd": "/etc/os-release",
                "match": "ID=debian"
            }]
        },
        "arch": {
            // No match --> rely on default matching
            "overrides": {
                "nginx": {
                    "name": "nginx2",
                    "version": "^1.0.0"
                },
                "mariadb": {
                    "cmd": [
                        "curl some_url",
                        "cd some_url && make install"
                    ]
                }
            }
        }
    },
    "macos": {
        "use": "homebrew"
    },
    "windows": {
        "use": "chocolatey"
    }
}
```