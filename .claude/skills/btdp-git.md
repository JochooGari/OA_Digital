---
description: "BTDP Git conventions, branch naming, commit messages, workflows, hooks and GitHub setup"
user_invocable: true
---

# BTDP Git Framework — Conventions & Workflows

Source : Confluence BTDP espace `BTDP` — sections 4.3 et 4.4

---

## 1. Branch Naming Conventions

### Categories

| Category | Prefix | Usage |
|----------|--------|-------|
| Feature | `feat/` | New feature implementation |
| Bug fix | `bugfix/` | Bug resolution |
| Hot fix | `hotfix/` | Urgent production fix |
| Technical debt | `debt/` | Improvements, refactoring |
| Work in progress | `wip/<trigram>/` | Draft work, not ready for review |
| MEP (mise en prod) | `mep/` | Production deployment |
| CI/CD | `cicd/` | Pipeline changes |

### Format

```
(wip/<trigram>/)?(feat|debt|bugfix|hotfix|cicd|mep)/(<theme>/)?<issue_ref>/<description>
```

### Validation Regex

```regex
^refs/heads/(master|develop|preprod|(wip/[a-z]{3}/)?(feat|debt|bugfix|hotfix|cicd|mep)/([A-Za-z]{4,15}/)?(((C|COS|DATADS|OM|OPERA|P360|R)?BTDP|BIMMK|BRIGHT|C2S|E2E|NEOA|SMART)[/-][0-9]{1,5}|[A-Z]{3,}[0-9]{3,10})/[a-z]{2}([a-z0-9-]?[a-z0-9])*)$
```

### Examples

```
feat/BTDP-422/elaborate-git-policy
bugfix/BTDP-001/repair-build
hotfix/BTDP-666/stop-that-hell-fire
wip/abk/feat/BTDP-441/define-git-conventions
feat/MYTHEME/STRY2102343/adding-new-elements
cicd/BTDP-100/update-pipeline
mep/BTDP-500/deploy-v2
```

### Protected branches

- `master` : production-ready code
- `develop` : integration branch
- `preprod` : pre-production

---

## 2. Commit Message Convention

Based on Angular JS convention.

### Format

```
[<issue-ref>](<tag>) <description>

<optional body>

Issue: <issue-ref>
```

### Tags

| Tag | Description |
|-----|-------------|
| `feat` | New feature or functionality |
| `bugfix` | Bug fix |
| `update` | Improvement to existing feature |
| `refactor` | Code refactoring (no behavior change) |
| `doc` | Documentation only |
| `test` | Adding/modifying tests |
| `ci` | CI/CD changes |
| `debt` | Technical debt reduction |

### Rules

- Header line: max **70 characters**
- Body lines: max **90 characters** each
- Issue reference is **mandatory** in header
- Issue is automatically added in footer by hooks

### Examples

```
[BTDP-422](feat) Implement auto licence cleaning script

Add Python script to revoke inactive Power BI Pro licences
via BTDP Groups API with batch processing.

Issue: BTDP-422
```

---

## 3. Git Workflows

### A. Rebase Workflow
Used to integrate changes simulating a new starting point.

```bash
git checkout develop
git checkout -b topic_branch
# ... work and commit ...
git fetch origin
git checkout develop && git pull --rebase
git rebase develop topic_branch
```

### B. Squash and Merge Workflow (most common)
Used for feature branches — squash all commits into one on merge.

```bash
# On GitHub PR: select "Squash and merge"
# Keeps develop history linear
```

### C. Merge Workflow (no fast-forward)
Used for production deployments — preserves full history.

```bash
git checkout master
git merge --no-ff gotoprod_branch
```

### D. Hotfix Workflow
Urgent production fix — branch from master, merge back to master AND develop.

```bash
git fetch
git checkout -b hotfix/BTDP-666/critical-fix origin/master
# ... fix and commit ...
# PR to master (squash and merge)
# Then replicate to develop to avoid desync
```

---

## 4. Git Hooks (btdp-git-utils)

Repository: `github.com/loreal-datafactory/btdp-git-utils`

### Client-side hooks

| Hook | Purpose |
|------|---------|
| `pre-commit` | Validate staged changes before commit |
| `commit-msg` | Check commit message format (tags, length, issue ref) |
| `prepare-commit-msg` | Auto-add issue reference from branch name |
| `pre-push` | Validate branch name before push |

### Server-side hooks

| Hook | Purpose |
|------|---------|
| `pre-receive` | Validate pushed branches and commits |
| `post-update` | Post-push actions |

### Setup

```bash
# Clone btdp-git-utils
git clone git@github.com:loreal-datafactory/btdp-git-utils.git

# Set hooks path (per repo)
git config --local core.hooksPath /path/to/btdp-git-utils/hooks

# Or globally for all BTDP repos
git config --global core.hooksPath /path/to/btdp-git-utils/hooks
```

---

## 5. GitHub Configuration

### Organisations

| Organisation | Purpose |
|-------------|---------|
| `loreal-datafactory` | Main: data services, use cases, tooling, POCs |
| `oa-datafactory-domains` | SDDS repositories |
| `oa-datafactory-usecases` | CDS (consumption) repositories |
| `loreal-cloudops` | GCP core services |
| `oa-datafactory-ops` | Infrastructure testing |

### Account setup

1. Create account with `@loreal.com` email
2. Username format: `<something>-oa` (e.g., `mmadi-oa`)
3. Profile name: `Firstname LASTNAME`
4. Make email **public** (uncheck "Keep my email addresses private")
5. Enable **2FA** (Google Authenticator preferred)
6. Add **SSH key** with SSO enabled
7. Add **GPG key** for commit signing
8. Create **Personal Access Token** for API/HTTPS access

### Repository rules

- Always **private**
- Created **empty** (no template)
- First commit: `git commit --allow-empty -m 'Initial commit'`
- Create `master` and `develop` branches from this empty commit
- Repository name: lowercase, hyphens (regex: `^[a-z]{3}([-_]?[a-z])*$`)
- Delete branches after PR merge

### Git config (.gitconfig)

```ini
[user]
    name = Firstname LASTNAME
    email = firstname.lastname@loreal.com
    signingKey = SHORT_GPG_KEY_SHA
[commit]
    gpgsign = true
[core]
    hooksPath = /path/to/btdp-git-utils/hooks
    excludesfile = /path/to/btdp-git-utils/config/btdp.gitignore
```

Use conditional includes for BTDP workspace:

```ini
[includeIf "gitdir:~/btdp-workspace/git/"]
    path = ~/btdp-workspace/git/workspace-btdp.gitconfig
```

---

## 6. SSH Setup

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "firstname.lastname@loreal.com"

# ~/.ssh/config
Host github.com
    HostName github.com
    User git
    AddKeysToAgent yes
    IdentityFile ~/.ssh/loreal.id_rsa
```

### Troubleshooting

```bash
# Restart SSH agent
eval "$(ssh-agent -s)"

# Check correct alias
git clone git@github.com:loreal-datafactory/repo.git
```

---

## Quick Reference — When creating a new branch

1. Check you're on `develop`: `git checkout develop && git pull --rebase`
2. Create branch with correct naming: `git checkout -b feat/BTDP-XXX/my-feature`
3. Commit with correct format: `git commit -m '[BTDP-XXX](feat) Description'`
4. Push: `git push -u origin feat/BTDP-XXX/my-feature`
5. Create PR targeting `develop` (squash and merge)
