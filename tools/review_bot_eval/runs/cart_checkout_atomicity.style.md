## Style — no findings

No hardcoded colors, gradients, or font families are added. `sellCart`'s queries stay inside
`DatabaseHelper`, where SQL belongs. No tab or screen registration is touched. No `print()` is
added. The two added `///` doc comments (`sellCart`, `checkoutCart`) describe what each public
method does, not a line-by-line narration of code beneath them — not the kind of comment §4.5
targets. PR title `feat(sales): add cart checkout` is Conventional Commits: valid type (`feat`),
valid scope (`sales`), imperative, lowercase, no trailing period.

## Insufficient context
None.
