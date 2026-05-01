_:
  @just --list

# Format and lint the package using ruff, and lint the examples using marimo.
lint:
  ruff format
  ruff check

# Run the test suite using pytest.
test:
  pytest

# Run tests with coverage report (requires pytest-cov).
test-cov:
  pytest --cov=metaconf --cov-report=term-missing --cov-fail-under=90

# Run static type checker.
typecheck:
  pyright src/metaconf

# Build the example notebooks.
examples:
  uv run --group examples jupytext --set-formats ipynb,md --execute docs/examples/*/*.md

# Build the documentation and serve it in the browser.
docs:
  uv run mkdocs build
