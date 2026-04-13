# Assignment 4 Buildroot — Learning Summary

## Step 1: Installing Mandatory Packages

### What to Learn

Buildroot is a **build system** that runs entirely on your Linux host machine and cross-compiles a complete embedded Linux system (kernel, bootloader, root filesystem, packages) for a target architecture (e.g. ARM).

Before Buildroot can do any of that, your **host** must have a set of standard tools installed.

### Key Concepts

- **Host vs Target**: The *host* is your development machine (x86 Ubuntu). The *target* is the embedded device (e.g. ARM board or QEMU). Buildroot runs on the host and produces output for the target.
- **Cross-compilation toolchain**: Buildroot needs tools like `gcc`, `make`, `binutils`, `perl`, `python3` on the host to orchestrate and run the build process.
- **Mandatory vs Optional packages**: Buildroot's documentation separates packages into mandatory (build will fail without them) and optional (needed only for specific features like menuconfig UI or certain download methods).

### Mandatory Buildroot Packages and Why

| Package | Purpose |
|---------|---------|
| `make` | Drives the entire Buildroot build system |
| `gcc` / `g++` | Compiles host-side tools used during the build |
| `binutils` (`ld`, `as`) | Linker and assembler utilities |
| `bash` | Buildroot scripts require bash specifically |
| `patch` | Applies patches to package source code |
| `gzip` / `bzip2` | Decompresses downloaded source tarballs |
| `perl` | Required by some build scripts |
| `tar` / `cpio` | Archives source and root filesystem images |
| `unzip` / `rsync` | Extract and sync package sources |
| `file` | Identifies file types during build |
| `bc` | Used in kernel Makefile calculations |
| `wget` | Downloads package source tarballs |
| `python3` | Required by some packages and Buildroot internals |
| `git` | Fetches packages hosted on git repositories |
| `diff` / `find` / `awk` / `sed` | Text processing used throughout build scripts |
| `libncurses-dev` | Enables the `menuconfig` ncurses UI for configuration |

### Verification with `which`

Use `which <binary>` or `command -v <binary>` to confirm a tool is installed and on your `$PATH`. Example:

```bash
which make      # → /usr/bin/make
which python3   # → /usr/bin/python3
```

Use `dpkg -l <package>` to check library packages that have no direct binary.

---

## Step 2: Adding Buildroot as a Git Submodule

### What to Learn

A **git submodule** lets you embed one git repository inside another. The outer (parent) repo records a pointer to a specific commit of the inner (submodule) repo — not the code itself.

This is the standard pattern for embedding Buildroot into a project because:
- Buildroot is a large, independent project with its own release cycle.
- You want to pin your project to a **specific, tested version** of Buildroot.
- You keep your customizations separate from the upstream Buildroot code.

### Key Commands

```bash
# Add a submodule, pinned to a specific branch
git submodule add -b 2024.02.x https://gitlab.com/buildroot.org/buildroot/ buildroot

# After cloning the parent repo elsewhere, initialize and fetch submodules
git submodule update --init --recursive
```

### What Gets Created

| File/Dir | Purpose |
|----------|---------|
| `.gitmodules` | Tracks submodule URL, path, and branch |
| `buildroot/` | The cloned Buildroot source tree |
| Parent repo commit | Records the exact commit hash of the submodule |

### Why Pin to a Branch (`2024.02.x`)

Buildroot uses **Long Term Support (LTS)** branches like `2024.02.x` for stability. These receive only bug and security fixes, making them safe for production embedded projects. The `.x` suffix means patch releases will be applied on top of the `2024.02` base release.

### Important: Committing the Submodule

After adding a submodule you must commit in the **parent repo** to save the submodule's commit hash:

```bash
git add .gitmodules buildroot
git commit -m "feat: add buildroot 2024.02.x as git submodule"
```

Without this commit, collaborators cloning your repo won't know which Buildroot commit to check out.

### Project Structure with `base_external`

```
Assignment-4-Buildroot/       ← Parent git repo
├── buildroot/                ← Git submodule (Buildroot source, untouched)
├── base_external/            ← Your customizations (packages, configs, overlays)
│   ├── Config.in
│   ├── external.mk
│   └── package/
├── build.sh                  ← Runs Buildroot pointing to base_external
└── .gitmodules
```

The `base_external` directory is a Buildroot **external tree** — it keeps your project-specific configurations and packages completely separate from the upstream Buildroot code. This is the recommended Buildroot workflow.

---

## Assignment 4 Complete — What We Built and Fixed

### Goal
Build a Buildroot image for QEMU AArch64, run `finder-test.sh` inside QEMU, collect the result, and pass the GitHub Actions CI.

---

### Repo Changes — `assignment3p2-msoubhi` (A3 code)

| File | Change | Why |
|------|--------|-----|
| `finder-app/finder.sh` | Shebang `#!/bin/bash` → `#!/bin/sh`; stripped CRLF line endings | Buildroot only has busybox ash (no bash); Windows CRLF made shebang `#!/bin/sh\r` which is an invalid interpreter path |
| `finder-app/finder-test.sh` | Used absolute paths `/usr/bin/writer` and `/usr/bin/finder.sh`; reads conf from `/etc/finder-app/conf/`; writes result to `/tmp/assignment4-result.txt` | `PATH` is minimal in QEMU script context; Buildroot installs to `/usr/bin/` |
| `assignments/assignment4/assignment4-result.txt` | Added: `The number of files are 10 and the number of matching lines are 10` | Required output file for assignment submission |

---

### Repo Changes — `Assignment-4-Buildroot`

| File | Change | Why |
|------|--------|-----|
| `base_external/external.desc` | Set `name: project_base` | Determines the Buildroot variable name used in external.mk — must match exactly |
| `base_external/external.mk` | Fixed `BR2_EXTERNAL_PROJECT_BASE_PATH` → `BR2_EXTERNAL_project_base_PATH` | Buildroot derives the variable name from `name:` in external.desc (case-sensitive, lowercase) |
| `base_external/Config.in` | Wired up aesd-assignments package menu entry | Without this the package never appears in menuconfig or gets built |
| `base_external/package/aesd-assignments/aesd-assignments.mk` | Set correct git commit hash and SSH repo URL; removed stray single quotes; added install rules for all scripts | Single quotes in Make become part of the variable value; SSH URL required (not HTTPS) for CI |
| `base_external/configs/aesd_qemu_defconfig` | Added `BR2_PACKAGE_DROPBEAR=y`, `BR2_TARGET_GENERIC_ROOT_PASSWD="root"`, `BR2_JLEVEL=1` | Dropbear = SSH server for QEMU access; root password for login; BR2_JLEVEL=1 avoids glibc race condition |
| `.github/workflows/github-actions.yml` | Updated action versions to `checkout@v4`, `ssh-agent@v0.9.0`; increased `timeout-minutes` to 1200 | Old versions deprecated on Node 20; 120-minute timeout not enough for a full Buildroot build |
| `clean.sh`, `build.sh`, `runqemu.sh` | Set git file mode to `100755` (executable) via `git update-index --chmod=+x` | NTFS filesystem doesn't store Unix executable bits; git stored them as `100644` causing CI validation to fail |

---

### Key Problems and Root Causes

#### 1. `external.mk` wrong variable name
Buildroot derives the external tree variable name from the `name:` field in `external.desc`.
With `name: project_base`, the correct variable is `BR2_EXTERNAL_project_base_PATH`.
Using `BR2_EXTERNAL_PROJECT_BASE_PATH` (uppercase) caused the package to silently never be found.

#### 2. Single quotes in `.mk` file
```makefile
# WRONG — quotes become part of the value
AESD_ASSIGNMENTS_VERSION = 'abc123'
# CORRECT
AESD_ASSIGNMENTS_VERSION = abc123
```

#### 3. `finder.sh` not found in QEMU
Two layered bugs:
- Shebang was `#!/bin/bash` but Buildroot's busybox only has `/bin/sh`
- File had Windows CRLF endings, making the shebang `#!/bin/sh\r` — Linux kernel rejects `\r` in interpreter paths

Diagnosed with: `xxd finder.sh | head -2` (looked for `0d 0a` bytes)

#### 4. `writer` / `finder.sh` not found at runtime
Called without absolute paths in `finder-test.sh`. In QEMU's minimal shell environment, `PATH` doesn't include `/usr/bin` by default. Fixed to use `/usr/bin/writer` and `/usr/bin/finder.sh`.

#### 5. `scp` fails — no sftp-server
Dropbear does not include an sftp-server binary. Used this instead:
```bash
ssh -p 10022 root@localhost 'cat /tmp/assignment4-result.txt' > result.txt
```

#### 6. glibc race condition on CI
Error: `undefined reference to __lll_lock_wake_private` when linking glibc's `ld.so`.

**Root cause**: glibc 2.38 has a Makefile dependency bug in its `elf/` subdirectory — `ld.so` is linked before `nptl/lowlevellock.o` is guaranteed to be built when using parallel make. This is triggered non-deterministically with `-j > 1`.

**History of attempts**:
- `-j13` (default auto): race condition hit every time → linker error
- `-j8`, `-j4`: race condition still occurs
- `-j1`: no race condition, but took >20 hours on NTFS (Docker bind-mount) → timeout
- **Final fix**: Move runner to WSL2 native ext4 filesystem + `BR2_JLEVEL=1`
  - On ext4, single-threaded glibc build completes in ~30-60 minutes
  - No race condition possible with `-j1`

#### 7. CI timeout
Original `timeout-minutes: 120` insufficient for a full Buildroot build from scratch.
Increased to `timeout-minutes: 1200` (20 hours).

#### 8. NTFS vs ext4 — the filesystem issue
The GitHub Actions self-hosted runner was installed at `/mnt/c/...` (Windows NTFS, mounted via WSL2).
Docker bind-mounts the runner's `_work` directory into the container.
When `_work` is on NTFS:
- File I/O is ~10-50x slower than native Linux
- glibc parallel build race conditions are exacerbated
- Single-threaded build took >20 hours → always timed out

**Fix**: Reinstall runner in `~/actions-runner-assignment4/` (WSL2 native ext4):
```bash
mkdir ~/actions-runner-assignment4
cd ~/actions-runner-assignment4
# download + configure + run runner here
```

---

### Local QEMU Testing Workflow

```bash
# 1. Build (run twice — first creates .config, second builds)
./build.sh
./build.sh

# 2. Run QEMU
./runqemu.sh
# Login: root / root

# 3. Inside QEMU
finder-test.sh
cat /tmp/assignment4-result.txt

# 4. Copy result out (Dropbear has no sftp-server, use ssh cat)
ssh -p 10022 root@localhost 'cat /tmp/assignment4-result.txt' > assignment4-result.txt
```

---

### Lessons Learned

| Lesson | Detail |
|--------|--------|
| Buildroot external tree variable naming | Derived from `name:` in `external.desc` — case-sensitive, exact match required |
| Make variable quoting | Never quote values in `.mk` files — quotes are literal in Make |
| CRLF line endings | Windows editors add `\r\n`; Linux scripts fail silently on `\r` in shebangs. Use `sed -i 's/\r//' file` to fix |
| Busybox shell | Buildroot images don't have bash by default — always use `#!/bin/sh` and POSIX sh syntax |
| git executable bits on NTFS | NTFS ignores Unix permissions; use `git update-index --chmod=+x` to store the correct mode in git |
| Self-hosted runner filesystem | Install on WSL2 native ext4, not on `/mnt/c/` (NTFS) — parallel builds fail on NTFS via Docker |
| glibc 2.38 parallel build bug | A known Makefile dependency issue in `elf/`; use `BR2_JLEVEL=1` as the workaround |
