# Intentional CI demo — Лабораторна №3 — must NOT be merged.
# Demonstrates branch protection blocking a PR with failing pytest.
import pytest


def test_demo_intentional_failure() -> None:
    pytest.fail("intentional CI demo for Lab 3 — branch protection should block this PR")
