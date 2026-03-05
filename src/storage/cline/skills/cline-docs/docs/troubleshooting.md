# Troubleshooting

## Terminal Issues

### Quick Fix: Background Execution Mode

Most terminal issues are solved by switching to background execution:

1. Click **Settings** in Cline panel
2. Go to **Terminal Settings**
3. Set **Terminal Execution Mode** → **Background Exec**

### Other Fixes

| Issue | Solution |
|-------|----------|
| General terminal problems | Switch to bash in Terminal Settings |
| Commands timing out | Increase shell integration timeout to 10 seconds |
| Terminal conflicts | Disable "aggressive terminal reuse" |

### Platform-Specific

**macOS + Oh-My-Zsh:**
```bash
echo 'export TERM=xterm-256color' > ~/.zshrc-vscode
echo 'export PAGER=cat' >> ~/.zshrc-vscode
```

**Windows PowerShell:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**WSL:**
- Open folder from WSL: `code .`
- Select "WSL Bash" in Terminal Settings
- Increase timeout to 15 seconds

---

## Networking & Proxies

### VSCode Extension

Uses VSCode's built-in proxy settings automatically. See VSCode docs for proxy server support.

### CLI

Set environment variables before running `cline`:

```bash
# macOS/Linux
export https_proxy=http://proxy.company.com:8080
export http_proxy=http://proxy.company.com:8080

# With authentication
export https_proxy=http://username:password@proxy.company.com:8080

# Custom CA certificate
export NODE_EXTRA_CA_CERTS=/path/to/ca-certificate.pem
```

**Windows:**
```cmd
set https_proxy=http://proxy.company.com:8080
set NODE_EXTRA_CA_CERTS=C:\path\to\ca-certificate.crt
```

### JetBrains IDEs

Settings → Appearance & Behavior → System Settings → HTTP Proxy

### Bypass Proxy for Localhost

```bash
export no_proxy=localhost,127.0.0.1,.local
```

### Limitations

- Only HTTP proxies supported (not SOCKS)
- No PAC script support
- Basic username/password auth only

### Testing Proxy

```bash
export https_proxy=http://proxy.company.com:8080
curl -vv https://api.anthropic.com
```

Check logs: `~/.cline/cline-core-service.log`

---

## Task History Recovery

### Quick Recovery

1. Open Command Palette (`Cmd/Ctrl + Shift + P`)
2. Run **"Cline: Reconstruct Task History"**
3. Confirm action

### Storage Paths

| Platform | Path |
|----------|------|
| macOS | `~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/` |
| Windows | `%APPDATA%\Code\User\globalStorage\saoudrizwan.claude-dev\` |
| Linux | `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/` |

For Insiders: replace `Code` with `Code - Insiders`.

### Directory Structure

```
saoudrizwan.claude-dev/
├── state/
│   ├── taskHistory.json          # Main index
│   └── taskHistory.backup.*.json # Backups
├── tasks/
│   └── <task-id>/                # Individual task data
└── checkpoints/
    └── <workspace-hash>/
        └── .git/                 # Shadow Git for snapshots
```

### Restore from Backup

```bash
cd ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/state/
ls taskHistory.backup.*.json
cp taskHistory.backup.1234567890.json taskHistory.json
```

### Migrating to New Machine

1. Copy `saoudrizwan.claude-dev` folder from old machine
2. Install IDE and Cline on new machine
3. Close IDE
4. Paste folder to same storage path
5. Launch IDE

Works cross-platform (Windows → macOS works).

### Common Problems

| Problem | Cause | Solution |
|---------|-------|----------|
| History empty after update | Index corrupted | Run recovery command |
| History lost after reinstall | VS Code keeps extension data | Run recovery command |
| "No tasks found" | `tasks/` folder missing | Check correct storage path |
| Some tasks missing after recovery | Corrupted task folders | Check error messages |

## Cross-References

- Terminal settings → See Settings panel
- Checkpoints for code recovery → See [core-workflows.md](core-workflows.md)
- CLI troubleshooting → See [cli.md](cli.md)