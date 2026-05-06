# dirconf

[![PyPI version](https://img.shields.io/pypi/v/dirconf)](https://pypi.org/project/dirconf/)
[![Python versions](https://img.shields.io/pypi/pyversions/dirconf)](https://pypi.org/project/dirconf/)
[![License](https://img.shields.io/pypi/l/dirconf)](https://github.com/jmarshrossney/dirconf/blob/main/LICENSE)
[![CI](https://github.com/jmarshrossney/dirconf/actions/workflows/ci.yml/badge.svg)](https://github.com/jmarshrossney/dirconf/actions/workflows/ci.yml)
[![Docs](https://github.com/jmarshrossney/dirconf/actions/workflows/docs.yml/badge.svg)](https://jmarshrossney.github.io/dirconf)

`dirconf` is a Python tool for declaratively specifying what a valid configuration directory looks like.

I wrote this because I sometimes have to work with quite old scientific models that require various configuration files and data inputs in various formats to be present in various locations.
I was (and remain) concerned about how easy it can be to misconfigure certain models without realising, and how common workflows compromise reproducibility.

`dirconf` helps by

1. Allowing the user to describe the structure of a directory representing a valid configuration, and validate real directories against this description.

2. Facilitating the generation of new configurations and metadata programmatically, in Python, as opposed to copying and editing files by hand or writing shell scripts.

3. Providing a consistent mechanism through which complex, distributed configurations in legacy formats can be validated using excellent tools such as [JSON Schema](https://json-schema.org/) and [Pydantic](https://docs.pydantic.dev/).

Configurations are specified using Python [dataclasses](https://docs.python.org/3/library/dataclasses.html); `dirconf` has no dependencies beyond the standard library.

For full user documentation and examples please visit **[https://jmarshrossney.github.io/dirconf/](https://jmarshrossney.github.io/dirconf/)**.

## Installation

```sh
pip install dirconf
```

or with `uv`:

```sh
uv add dirconf
```

or the equivalent command for other package managers (poetry etc).


## Development

Contributions are welcome!

Please open a Pull Request against the `main` branch.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for full details.

