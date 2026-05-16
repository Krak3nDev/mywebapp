# CI/CD runbook (Лабораторна №3)

Усі кроки нижче — **ручна частина**, яку студент виконує сам (ВМ, токени, GitHub UI).
Очікуваний час: **2.5–3.5 години**.

## 0. Передумови

- GitHub репозиторій: `Krak3nDev/mywebapp` (вже на місці).
- Хост: на якому виконуватимуться скрипти `target-node-install.sh`, `runner-bootstrap.sh` — це **дві окремі** Ubuntu 24.04 LTS ВМ.
- Інструменти на робочій машині: `git`, `gh` CLI, ssh.

## 1. Запровадження двох ВМ

Обидві — Ubuntu 24.04 Server, мінімум 2 vCPU / 2 GiB RAM / 20 GiB disk.
Підняти можна у DigitalOcean, Hetzner, AWS, Multipass — без різниці.

| Роль | hostname (приклад) | IP | Доступ |
| --- | --- | --- | --- |
| target | `mywebapp-target.lan` | публічний | 22 + 80 наповнюється `target-node-install.sh` |
| runner | `mywebapp-runner.lan` | публічний/приватний | 22 |

**Важливо:** target ≠ runner. Розгортання з runner-ВМ на саму себе **заборонено** специфікацією.

## 2. Налаштування target-node

```bash
# на target ВМ як root
git clone https://github.com/Krak3nDev/mywebapp.git
cd mywebapp
sudo bash deploy/target-node-install.sh
```

Скрипт встановить:
- docker + docker compose plugin
- nginx (через контейнер у compose.prod.yml)
- postgres (через контейнер)
- системний користувач `mywebapp`
- /opt/mywebapp/ з compose.prod.yml + nginx conf + migrate.sh
- /opt/mywebapp/.env з рандомними паролями (зберігається між запусками)
- systemd unit `mywebapp-container.service`
- ufw firewall (22 + 80 in, решта deny)

Перевірка:
```bash
sudo systemctl status mywebapp-container.service   # disabled до першого деплою
cat /opt/mywebapp/.env | grep IMAGE                # IMAGE=ghcr.io/krak3ndev/mywebapp:stable
```

## 3. Налаштування runner-ВМ

```bash
# на runner ВМ як root
git clone https://github.com/Krak3nDev/mywebapp.git
cd mywebapp
sudo bash deploy/runner-bootstrap.sh
```

Скрипт завантажить runner archive у `/opt/actions-runner` під користувачем `runner`. Реєстрація — **вручну**, бо токен має короткий TTL і не повинен потрапляти у репо.

```bash
# 1. Відкрити: https://github.com/Krak3nDev/mywebapp/settings/actions/runners/new
#    обрати Linux x64. Скопіювати --token.
# 2. На runner ВМ:
cd /opt/actions-runner
sudo -u runner ./config.sh \
    --url https://github.com/Krak3nDev/mywebapp \
    --token <PASTE_TOKEN> \
    --labels lab3-runner \
    --unattended
sudo ./svc.sh install runner
sudo ./svc.sh start

# 3. На GitHub: runner з'явиться у списку як online з лейблом `lab3-runner`.
```

## 4. GitHub Secrets

У `Settings → Secrets and variables → Actions → New repository secret`:

| Secret | Значення | Як отримати |
| --- | --- | --- |
| `TARGET_HOST` | публічний IP/DNS target-ВМ | з провайдера |
| `TARGET_USER` | користувач для SSH (наприклад `root` або створений deploy-юзер) | з провайдера |
| `TARGET_SSH_KEY` | приватний ключ у форматі OpenSSH | згенерувати `ssh-keygen -t ed25519 -f deploy_key`, публічну частину покласти в `~/.ssh/authorized_keys` на target |
| `GHCR_READ_TOKEN` | classic PAT з scope `read:packages` (АБО опустити, якщо пакет публічний) | https://github.com/settings/tokens → New (classic) |

**Альтернатива до PAT:** зробити пакет `mywebapp` публічним у `https://github.com/users/Krak3nDev/packages/container/mywebapp/settings`. Тоді `docker pull` працює анонімно і `GHCR_READ_TOKEN` не потрібен (deploy step пропускає `docker login` якщо token порожній).

> **Чому classic PAT, а не fine-grained:** fine-grained PAT не підтримує package scopes для GHCR (стан 2026).

## 5. GitHub Actions налаштування

### 5a. Fork-PR approval (security)

`Settings → Actions → General → Fork pull request workflows from outside collaborators` →
**Require approval for all outside collaborators**. Це блокує запуск malicious workflow з fork-PR на self-hosted runner.

### 5b. Branch protection (виконати ПІСЛЯ першого успішного PR-ран)

Після того як перший PR пройде workflow зеленим, GitHub UI запам'ятає назви job'ів. Тоді:
`Settings → Branches → Add rule → Branch name pattern: main`:
- ✓ Require a pull request before merging
- ✓ Require status checks to pass before merging
  - ✓ Require branches to be up to date before merging
  - Required checks: `lint (ruff + mypy + hadolint + shellcheck + yamllint + actionlint)` та `test (pytest + coverage >=40%)`
- ✓ Do not allow bypassing the above settings

> Важливо: назви required-checks мають збігатися з `name:` у workflow ТОЧНО (включно з дужками). Тому enable після першого ран'у — GitHub автокомплітить exact names.

## 6. Перший прогін

```bash
# на робочій машині
git checkout -b ci/lab3-bootstrap
# (нічого не змінюємо у коді — просто триггеримо ран)
git commit --allow-empty -m "ci: smoke trigger"
git push -u origin ci/lab3-bootstrap
gh pr create --title "ci: lab3 bootstrap" --body "smoke" --base main
```

Очікувано: lint + test зелені; build пропускається на PR. Після merge до main — build запушить `ghcr.io/krak3ndev/mywebapp:latest` + `sha-<full>`.

## 7. Перший deploy через анотований тег

```bash
git checkout main && git pull
git tag -a v0.1.0 -m "first deploy of Lab 3"
git push origin v0.1.0
```

Очікувано: всі 5 jobs зелені.
- build push `:stable` + `:v0.1.0` у GHCR.
- deploy SSH у target, `sed -i .env` IMAGE=…:v0.1.0, `systemctl restart mywebapp-container.service`.
- verify ходить `curl` по target.

`curl http://${TARGET_HOST}/items` — має повернути JSON.

## 8. Демонстрація failed-verify (Option α)

Замість намагання re-run verify ізольовано — створюємо deliberately broken release:

```bash
# тимчасово ламаємо очікування у verify-deploy.sh:
sed -i 's|404 "${BASE}/admin"|200 "${BASE}/admin"|' scripts/verify-deploy.sh
git commit -am "demo: deliberately broken verify expectation"
git tag -a v0.0.0-demo-broken -m "demo: failing verify"
git push origin main v0.0.0-demo-broken

# Pipeline runs: build/deploy зелені, verify ❌. Зберегти log.
# Потім — revert і нормальний реліз:
git revert HEAD --no-edit
git push origin main
```

## 9. Демонстрація blocked PR

```bash
git checkout -b demo/failing-test
cat > tests/test_demo_fail.py <<'EOF'
def test_demo_fail() -> None:
    assert False, "intentional CI demo — must NOT be merged"
EOF
git add tests/test_demo_fail.py
git commit -m "demo: deliberately failing test"
git push -u origin demo/failing-test
gh pr create --title "demo: failing test (do not merge)" \
             --body "Intentional failure for Lab 3 demonstration." \
             --base main
# CI fails red. Branch protection блокує merge button. Зберегти посилання на PR.
```

## 10. Після демо

- Скріншоти passing PR + blocked PR + два deploy логи + coverage artifact → у `mini-report` PDF.
- Зупинити або **видалити** runner-ВМ (per spec — щоб не залишилися активні self-hosted runners на публічному repo).
- На GitHub: `Settings → Actions → Runners` → видалити offline runner.

## Troubleshooting

- **deploy job висне на ssh:** перевір `ssh -i deploy_key root@$TARGET_HOST` руками; вірогідно ssh-keyscan не дотягнувся (firewall на 22) або `accept-new` не спрацював.
- **GHCR push 401/403:** workflow має `permissions: packages: write` (вже виставлено) і `${{ secrets.GITHUB_TOKEN }}` — без додаткових PAT. Зміни в `IMAGE_NAME` вже lowercased у `compute meta` step.
- **systemd unit failed:** `journalctl -u mywebapp-container.service` на target; перевірити що `/opt/mywebapp/.env` має IMAGE+POSTGRES_PASSWORD.
- **verify ❌ на нормальному релізі:** `docker compose -f /opt/mywebapp/compose.prod.yml ps` — побачити який сервіс не healthy.
