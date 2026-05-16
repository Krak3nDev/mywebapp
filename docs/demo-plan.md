# Демонстрація (для звіту в Classroom)

Специфікація вимагає 5 артефактів. Послідовність дій + локація логів:

## 1. PR, який успішно злито (passing)

- Гілка: `demo/passing` (наприклад, дрібна правка README або typo fix).
- Запушити, відкрити PR, дочекатися зеленого CI, **squash & merge**.
- Скріншот: GitHub PR page з усіма check marks ✅; "This branch has no conflicts with the base branch".
- Зберегти: посилання PR + знимок merged status.

## 2. PR, який заблоковано branch protection (failing)

- Гілка: `demo/failing-test`.
- Створити `tests/test_demo_fail.py` з `assert False`. Можна додати коментар "intentional CI demo".
- Запушити, відкрити PR.
- Очікувано: `test` job червоний; "Merge button" disabled; повідомлення про required checks.
- Скріншот: PR page з ❌ + закритий merge button.
- **Не мерджити.** Можна закрити PR після зняття скриншоту.

## 3. Лог успішного розгортання

- Тег: `v0.1.0` (анотований).
- Pipeline зелений на всіх 5 jobs.
- Скріншот: workflow run summary + deploy job step з `systemctl restart` виводом.
- Зберегти: експорт повного логу deploy job у `mini-report-logs/v0.1.0-deploy.log`.

## 4. Лог успішного розгортання з неуспішною верифікацією

- Тег: `v0.0.0-demo-broken` (попередньо змінити `verify-deploy.sh` так щоб одна перевірка падала — наприклад `check_code "admin 404" 200` замість `404`).
- Pipeline: build ✅ + deploy ✅ + verify ❌.
- Скріншот: workflow run з ✅/❌ pattern + verify job логом.
- Зберегти: deploy + verify logs у `mini-report-logs/v0.0.0-demo-broken-{deploy,verify}.log`.
- Після — `git revert` правки `verify-deploy.sh`, push, нормальний tag.

## 5. Звіт по покриттю коду тестами

- Артефакт `coverage-html` з successful run на main / на тегу.
- Скачати → відкрити `htmlcov/index.html` → скріншот загальної таблиці (per-file Cover %).
- Опційно: вставити `coverage.xml` `<line-rate>` значення у звіт.
- Локальний показник зараз: **86.39%** (gate 40%).

---

## Mini-report (PDF/markdown для Classroom)

Структура:

1. Титульна сторінка: Бігіч Назар, Лаб №3, варіант 5.
2. Архітектура CI: схема (lint→test→build→deploy→verify) + tags matrix.
3. Self-hosted runner: опис ВМ + лейбли + чому manual registration.
4. Артефакт #1: passing PR — скріншот + посилання.
5. Артефакт #2: blocked PR — скріншот + причина блокування.
6. Артефакт #3: успішний deploy — workflow URL + key log lines.
7. Артефакт #4: failed verify — workflow URL + key log lines + які перевірки впали.
8. Артефакт #5: coverage report — таблиця per-file %.
9. Висновки: 3-4 короткі речення без води.

**Анти-флаф нагадування з лаби №2:** жодних "на цій лабораторній роботі я навчився".
