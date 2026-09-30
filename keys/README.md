# Keys

`dev_signing.key` is the **private** Ed25519 key that `tools/pack.py` signs
images with. Its public half is compiled into the bootloader
(`src/crypto/anchor-trust_anchor.ads`).

It is a test key, committed on purpose so the seed works right after cloning.
On a real product the private key never leaves the vendor's signing machine,
and never goes in a repository.

`python3 tools/keygen.py --force` makes a new pair.
