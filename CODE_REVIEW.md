# Code Review: metaconf

Here is a thorough code review of the `metaconf` package, organized by category.

---

## Correctness

**1. `filter_write` test signature mismatch** (`filter.py:69-73,96`)

The type annotation says `test: Callable[[Path], bool]`, yet the wrapper calls `test(Path(path), data, **kwargs)` — passing more arguments than the annotated signature allows. A `Callable[[Path], bool]` will fail at runtime if `test` doesn't accept extra positional/keyword args. The `filter_missing` write test (`lambda path, data, **_: ...`) works only because the lambda explicitly accepts the extra arguments. This type annotation is misleading and will confuse users writing custom write tests.

**2. `filter` class decorator mutates the class in-place** (`filter.py:136-150`)

Rather than returning a new class, `cls.read` and `cls.write` are monkey-patched. Any reference to the original class (including subclasses that haven't yet been decorated) will also see the mutation. This is surprising and can cause subtle bugs if the same class is used with and without filtering in different contexts.

**3. `Node.__post_init__` double-instantiates handlers** (`node.py:38-43`)

The handler factory is called once in validation (`handler_inst = handler()`) and then again later when `handler()` is called during `read`/`write`. Handlers with side effects in `__init__` will be triggered twice. The validation instance is thrown away. Consider caching or deferring validation.

**4. `path_to_node` incorrect type annotation** (`node.py:56`)

`Callable[str | PathLike, Node]` should be `Callable[[str | PathLike], Node]`. Without the inner brackets, `Callable` doesn't parameterize correctly — this is a syntax-level mistake in the type annotation.

**5. Assertions used for input validation** (`handler.py:54-58`, `filter.py:134`)

`assert isinstance(name, str)`, `assert isinstance(handler(), Handler)`, and `assert read or write` can all be silently disabled under `python -O`. These should be proper `TypeError`/`ValueError` raises. This is a particularly insidious bug because it means optimized builds skip handler validation entirely.

**6. `_str_is_path` heuristic is fragile** (`config.py:219-224`)

`Path(s).is_relative_to(Path.cwd())` is always true for any relative path (that's what "relative" means), making the other two conditions (`exists()`, `is_absolute()`) redundant for relative paths. More critically, any non-JSON string will fall through to this branch and be treated as a file path, producing confusing errors rather than a clear message.

**7. `MetaConfig.__call__` doesn't round-trip correctly** (`config.py:33-35`)

`dataclasses.asdict(self)` recursively converts all fields — including `Node` objects whose `handler` is a callable — into plain dicts. When `type(self)(**...)` reconstructs, those callables won't survive. The TODO acknowledges this, but it's a real correctness bug for any non-trivial usage.

**8. `WriteMethod` type alias doesn't reflect keyword-only semantics** (`handler.py:36`)

`WriteMethod = Callable[[Handler, Path, Any, bool], None]` doesn't capture that `overwrite_ok` is keyword-only (`*`). This means type checkers won't enforce the correct calling convention.

---

## Simplicity

**9. Too many input representations for `Node` creation**

A Node can be created from: a `Node`, a `dict` with `handler`, a `dict` without `handler`, a `str`/`PathLike`, or a single-element dict `{"path": ...}`. This creates a large combinatorial space in `to_node`, `path_to_node`, `dict_to_node`, and the `_make_metaconfig` branches. Consider narrowing the supported input forms and making users be explicit.

**10. `MISSING` as a class rather than a sentinel object** (`filter.py:11-12`)

The conventional Python pattern is `MISSING = object()`. A class is instantiable (`MISSING()`), which could produce confusing isinstance checks down the line. The docstring says "sentinal" (also a typo for "sentinel").

**11. `switch_dir` mechanism is process-global state** (`utils.py:11-31`)

Using `os.chdir` to manage paths means every `read`/`write` call temporarily changes the process's working directory. This is not thread-safe and not reentrant. It would be simpler and more robust to resolve paths explicitly rather than relying on `os.chdir`.

---

## Maintainability

**12. Transforms via metadata are opaque** (`config.py:25-27`, `node.py:54-66`)

The `__post_init__` method checks for a `transform` key in field metadata and applies it. This transform is set deep inside `_make_metaconfig` and there's no visible trace on the resulting class that this transformation happens. Someone reading a `MetaConfig` subclass has no way to know transforms are being applied without reading the metaclass construction code.

**13. Global mutable `handler_registry`** (`handler.py:42`)

A module-level `OrderedDict` that's mutated by `register_handler` is effectively global state. Tests that register handlers can bleed into each other, and there's no way to scope a registry to a particular use case. Consider making the registry an instance that can be passed around.

**14. `parse_handler` does too much** (`handler.py:66-79`)

This single function handles: registry key lookups, dotted-string module imports, and callable validation. These are three distinct responsibilities that would benefit from being separate functions, especially since the dotted-import path (`module.Class`) is both powerful (arbitrary code execution) and error-prone.

---

## Robustness

**15. Path `..` validation is CWD-dependent and unreliable** (`node.py:32-33`)

`path.resolve().is_relative_to(Path.cwd())` depends on the working directory at `Node` instantiation time, not at read/write time. Since `switch_dir` changes the CWD during operations, this check can produce both false positives and false negatives depending on when the `Node` is created vs. when it's used.

**16. TOCTOU in `MetaConfig.write`** (`config.py:75-77`)

There's a time-of-check-to-time-of-use gap between `path.is_dir()` and `path.mkdir()`. In concurrent scenarios, another process could create/remove the directory in between.

**17. `infer_handler_from_path` implicit priority** (`handler.py:98`)

When multiple handlers match a file extension, the last-registered one wins silently. The warning only fires when there are duplicates, but doesn't tell the user *which* handler was selected. This should at minimum be deterministic in a documented way, or require the user to be explicit when there's ambiguity.

**18. `switch_dir.__exit__` doesn't handle edge cases** (`utils.py:29-31`)

If the original directory has been deleted between `__enter__` and `__exit__`, `os.chdir(self.old)` will raise, and the process will be left in the wrong directory.

**19. `_make_metaconfig` default_factory re-validates on every access** (`config.py:175-176`)

`default_factory=lambda p=path, h=handler: Node(p, h)` creates a fresh `Node` each time the default is accessed, running full `__post_init__` validation (including handler instantiation and path checks). This is redundant overhead.

**20. Test coverage is thin** (`tests/`)

- `test_config.py` has only 2 tests (one of which just calls `.tree()` on an empty `MetaConfig`).
- `test_dynamic_construction.py` tests spec loading but doesn't test `read`/`write` at all.
- There are no tests for: `filter`/`filter_read`/`filter_write`, `Node` path validation, `switch_dir`, `parse_handler`/`infer_handler_from_path`, `to_node`/`path_to_node`, error paths, or edge cases.

---

## Summary of Priority Issues

| Priority | Issue | Location |
|----------|-------|----------|
| High | Assertions instead of exceptions (disabled by `-O`) | `handler.py:54-58`, `filter.py:134` |
| High | `filter` mutates class in-place | `filter.py:136-150` |
| High | `filter_write` test signature annotation is wrong | `filter.py:69-73` |
| High | No meaningful test coverage | `tests/` |
| Medium | `Node.__post_init__` double-instantiates handlers | `node.py:38-43` |
| Medium | `path_to_node` return type annotation syntax error | `node.py:56` |
| Medium | `__call__` doesn't round-trip with callables | `config.py:33-35` |
| Medium | `..` path validation is CWD-dependent | `node.py:32-33` |
| Medium | `_str_is_path` heuristic replaces errors with confusion | `config.py:219-224` |
| Low | Global mutable handler registry | `handler.py:42` |
| Low | `MISSING` should be a sentinel object, not a class | `filter.py:11-12` |
| Low | `switch_dir` relies on `os.chdir` (not thread-safe) | `utils.py:11-31` |