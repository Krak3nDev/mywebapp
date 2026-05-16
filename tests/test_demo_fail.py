# Intentional CI demo — Лабораторна №3 — must NOT be merged.
# Demonstrates branch protection blocking a PR with failing tests.


def test_demo_intentional_failure() -> None:
    assert False, "intentional CI demo for Lab 3 — branch protection should block this PR"
