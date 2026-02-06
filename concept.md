# Tendrils

## Declarative, cross-platform automation

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