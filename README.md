# Templates

A collection of miscellaneous templates.

## Available Templates

- **dev** (default): Development environment starter with a `flake.nix` and `.envrc` file.
- **python**: Python development environment with common tools like `pytest` and `ruff`.

## Usage

> Initialize a new project using the default template:
>
> ```bash
> nix flake init -t github:Nanagalaxy/templates
> ```

> Initialize using a specific template:
>
> ```bash
> nix flake init -t github:Nanagalaxy/templates#dev
> ```

> Initialize from a local path (if you have cloned the repository):
>
> ```bash
> nix flake init -t path:/path/to/templates
> ```
