# iqc-forge-install

Public, zero-secrets entrypoint for setting up a new IQC machine.

## One-liner (fresh Windows 11 machine)

Open any PowerShell window and run:

```powershell
irm https://raw.githubusercontent.com/Txmarshall/iqc-forge-install/main/install.ps1 | iex
```

That's it. The installer:

1. Confirms `winget` is available (built into Windows 11).
2. Installs **git** and the **GitHub CLI** if missing.
3. Runs `gh auth login` (browser flow) if you're not already authenticated.
4. Clones the private **`iqc-forge-bootstrap`** repo to `~\.forge\iqc-forge-bootstrap`.
5. Runs `forge-bootstrap.ps1`, which installs the rest of the toolchain, clones
   the fleet, walks you through the age key (secure paste, validated on the spot),
   renders secrets, and verifies everything.

Re-running the one-liner is safe — it fast-forwards the bootstrap repo and re-runs
(the bootstrap is idempotent).

## Why a separate public repo?

The real bootstrap lives in a **private** repo because it references personal
paths, the fleet repo list, and machine names. This public repo holds only the
generic fetch-auth-clone-run logic — nothing sensitive — so the one-liner can be
fetched without authentication while the actual setup stays private.

## Forking / renaming

Edit `$Owner` and `$BootstrapRepo` at the top of `install.ps1`.
