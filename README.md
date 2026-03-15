# Дипломный проект Netology  
## Отказоустойчивая инфраструктура сайта в Yandex Cloud

### Архитектура

Инфраструктура построена в Yandex Cloud с использованием:

- Terraform
- Ansible
- Application Load Balancer
- Bastion host
- NAT Gateway

Схема:

Internet  
↓  
Application Load Balancer  
↓  
web1 (private VM)  
web2 (private VM)  
↓  
NAT Gateway  

Административный доступ:

Admin → Bastion → Web servers

---

# Terraform

Terraform используется для создания:

- VPC сети
- подсетей
- bastion VM
- web1 VM
- web2 VM
- security groups
- NAT Gateway
- Application Load Balancer

Файлы Terraform находятся в директории:

terraform/


---

# Ansible

Ansible используется для конфигурации web серверов.

Playbook устанавливает:

- nginx
- копирует статический сайт

ansible/


---

# Web серверы

Созданы две ВМ:

| VM | Zone |
|----|------|
| web1 | ru-central1-a |
| web2 | ru-central1-b |

Параметры:

2 vCPU
2GB RAM
10GB HDD


---

# Bastion host

Bastion используется для SSH доступа.

158.160.42.40


Подключение:

ssh -J ubuntu@158.160.42.40 ubuntu@web1.ru-central1.internal


---

# Проверка балансировщика

Публичный IP ALB:

158.160.227.114


Ответ:

HTTP/1.1 200 OK
server: ycalb


Сайт обслуживается nginx на web1/web2.

---

# Безопасность

- web серверы **не имеют внешнего IP**
- доступ только через bastion
- входящий HTTP только через ALB
- ключ `key.json` исключён из git

---

# Используемые технологии

- Yandex Cloud
- Terraform
- Ansible
- Nginx
