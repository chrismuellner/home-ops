# Home Ops
 
Single-node talos cluster.

## Setup

All CLI tools are pinned in [`mise.toml`](mise.toml) and locked with checksums in `mise.lock`.
Installing them also installs the lefthook git hooks:

```sh
mise trust && mise install
```

## Attribution

Special thanks to the following people and their repositories:
- [onedr0p](https://github.com/onedr0p/home-ops)
- [bjw-s](https://github.com/bjw-s/home-ops)
