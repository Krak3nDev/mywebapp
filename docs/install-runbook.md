# Розгортання на віртуальній машині

## Базовий образ

Офіційний **Ubuntu 24.04 LTS Server** (cloud image): <https://cloud-images.ubuntu.com/releases/24.04/release/>
Файл: `ubuntu-24.04-server-cloudimg-amd64.img` або відповідний ISO для встановлення з нуля.

## Вимоги до ресурсів ВМ

| Ресурс | Мінімум | Рекомендовано |
| --- | --- | --- |
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GiB | 2 GiB |
| Диск | 10 GiB | 20 GiB |
| Мережа | 1 NIC, доступ до інтернету для `apt update` під час інсталяції; порт 80 відкритий назовні; SSH-порт 22 відкритий назовні | те саме |

Спеціальних налаштувань при встановленні OS не потрібно: standard disk partitioning, OpenSSH server увімкнено за замовчуванням.

## Доступ

Cloud-image: SSH ключем як користувач **`ubuntu`** (default cloud user).
ISO-інсталяція: користувач, якого створили під час setup.

```bash
ssh ubuntu@<vm-ip>           # cloud-image
# або
ssh <your-user>@<vm-ip>      # звичайна інсталяція
```

## Розгортання

```bash
# на ВМ
git clone https://github.com/<your>/mywebapp.git
cd mywebapp
sudo bash deploy/install.sh
```

Скрипт ідемпотентний; повторний запуск збіжиться до того самого стану.

### Прапори install.sh

- `--skip-lockout` — не блокує дефолтного користувача. Корисно поки ви ще не перевірили, що `operator` справді може зайти SSH-сесією.

### Що скрипт робить

1. `00_preflight.sh` — перевіряє ОС, root, мережу; відмовляється локати поточного користувача.
2. `10_packages.sh` — `apt install` python3.12, postgresql, nginx, openssh-server.
3. `20_users.sh` — створює `student`/`teacher`/`mywebapp`/`operator` з потрібними правами і `chage -d 0`.
4. `30_postgres.sh` + `35_pg_hba.sh` — `listen_addresses='127.0.0.1'`, `pg_hba` тільки `127.0.0.1/32 scram-sha-256`, role + db.
5. `40_app_files.sh` — встановлює код у `/opt/mywebapp`, створює venv.
6. `50_config.sh` — генерує `/etc/mywebapp/config.toml` (`0640 root:mywebapp`).
7. `60_migrate.sh` — запускає міграції від користувача `mywebapp`.
8. `70_systemd.sh` — встановлює unit-файли, enable `mywebapp.socket`, start `mywebapp.service`.
9. `80_nginx.sh` — встановлює nginx site, `nginx -t`, reload.
10. `85_sudoers.sh` — `visudo -cf` перед `mv` у `/etc/sudoers.d/operator-mywebapp`.
11. `90_lockout.sh` — `gradebook`, sshd-config asserts, лочить default user.
12. `99_verify.sh` — фінальний smoke (alive/ready/items/allow-list).

## Ручна перевірка після інсталяції

```bash
# 1. live перевірка
bash scripts/smoke.sh --prod

# 2. систем-стейт
systemctl status mywebapp.service mywebapp.socket nginx.service postgresql.service
ss -tlnp | grep -E '80|8080|5432'
cat /home/student/gradebook                # → 5
stat -c '%a %U:%G' /etc/mywebapp/config.toml   # → 640 root:mywebapp
sudo -n -l -U operator                     # → MYWEBAPP_CTL alias

# 3. socket re-activation
sudo systemctl stop mywebapp.service
curl --max-time 3 http://127.0.0.1:8080/health/alive
systemctl is-active mywebapp.service       # → active

# 4. зовнішньо
nc -zv <vm-ip> 5432    # → refused
nc -zv <vm-ip> 8080    # → refused
curl http://<vm-ip>/items
curl -o /dev/null -w '%{http_code}' http://<vm-ip>/health/alive  # → 404
```

## Безпека lockout: КРИТИЧНО

`90_lockout.sh` блокує дефолтного користувача (`ubuntu` на cloud image).
**Перед закриттям root/student сесії**:

1. Зайдіть SSH-ом окремою сесією як `operator` із паролем `12345678`.
2. Завершіть мандатний `chage` діалог: введіть `12345678` поточним, потім встановіть новий пароль (мінімум 8 символів).
3. Виконайте `sudo systemctl status mywebapp.service` — має повернути 0.
4. Тепер можна закривати оригінальну сесію.

Якщо щось пішло не так і ви заблокували себе — використовуйте console access гіпервізора (Proxmox/VirtualBox/VMware/Hyper-V), увійдіть як `root` через rescue / single-user mode і відкатайте:

```bash
usermod -U ubuntu
chsh -s /bin/bash ubuntu
```
