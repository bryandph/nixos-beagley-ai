# BeagleY-AI BSP

Every public file under `modules/` is one dendritic flake-parts module.
Package expressions belong in `packages/`. Compose features by imports;
do not add private identity, specialArgs, or homegrown feature enable gates.

Use `nix run .#fmt` and targeted package/image/check builds. Stage new files
before flake evaluation. Linux outputs use configured Linux builders; do not
cap routine concurrency. There is no devenv dependency requiring `--impure`.

Keep firmware sources, hashes, licenses and ABI mappings in release metadata.
Preserve vendor notices. Never assume public downloads allow modification or
redistribution. Never introduce operator keys or credentials into the BSP.

Ethernet is the first milestone; all feasible board hardware remains in scope.
Never stop the system Device Manager remote processor. Never format, mount or
modify existing NVMe during initial acceptance. Use identified spare SD media.
Record physical verification separately from implemented support.
