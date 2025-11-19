#!/bin/bash
set -euo pipefail

##############################################
#   НАСТРОЙКИ (измени путь к SSH ключу)     #
##############################################

REGION="us-east-1"
IMAGE_ID="ami-053b0d53c279acc90"
INSTANCE_TYPE="t3.micro"

KEY_NAME="UbuntuKey"
KEY_PATH="./UbuntuKey.pem"

SECURITY_GROUP_ID="sg-060a0017c16b3b8bb"
SUBNET_ID="subnet-0837944fa2a2c8124"
INSTANCE_NAME="DevOpsTask4"

REMOTE_USER="ubuntu"

##############################################
#   ПРОВЕРКИ                                 #
##############################################

if ! command -v aws >/dev/null; then
  echo "ERROR: AWS CLI не установлен"
  exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
  echo "ERROR: SSH ключ не найден: $KEY_PATH"
  exit 1
fi

##############################################
# 1. CREATE INSTANCE
##############################################

echo "=== 1) Создаю EC2 инстанс..."

INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$IMAGE_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --region "$REGION" \
  --query "Instances[0].InstanceId" \
  --output text)

echo "Instance ID: $INSTANCE_ID"

##############################################
# 2. WAIT FOR RUNNING
##############################################

echo "=== 2) Ждём запуска инстанса..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
echo "Инстанс запущен."

##############################################
# 3. GET PUBLIC IP
##############################################

echo "=== 3) Получаю публичный IP..."
PUBLIC_IP=""

for i in {1..30}; do
  PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

  if [[ "$PUBLIC_IP" != "None" ]]; then
    break
  fi
  sleep 2
done

echo "Публичный IP: $PUBLIC_IP"

##############################################
# 3.5 WAIT FOR SSH
##############################################

echo "=== 3.5) Жду 60 секунд для старта SSH..."
sleep 60

##############################################
# 4. CREATE USER SETUP SCRIPT ON SERVER
##############################################

echo "=== 4) Загружаю и создаю setup_users.sh на сервере ==="

ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$PUBLIC_IP" "cat > setup_users.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

echo "--- НАСТРОЙКА ПОЛЬЗОВАТЕЛЕЙ ---"

########################################
# 0. INSTALL ACL
########################################
sudo apt-get update -y
sudo apt-get install -y acl

########################################
# 1. adminuser (safe password prompt)
########################################
echo "[1] Создаю adminuser..."
sudo adduser --gecos "" adminuser
echo "[Введите пароль для adminuser]"
sudo passwd adminuser
sudo usermod -aG sudo adminuser

########################################
# 2. poweruser (passwordless login)
########################################
echo "[2] Создаю poweruser (вход без пароля)..."
sudo adduser --gecos "" --disabled-password poweruser

# включаем вход без пароля через shadow
sudo sed -i 's#^poweruser:[^:]*#poweruser:#' /etc/shadow

########################################
# 3. iptables permission
########################################
echo "[3] Даю poweruser право iptables..."
echo "poweruser ALL=(root) NOPASSWD: /usr/sbin/iptables" | sudo tee /etc/sudoers.d/poweruser-iptables >/dev/null
sudo chmod 440 /etc/sudoers.d/poweruser-iptables

########################################
# 4. only poweruser can read /home/adminuser
########################################
echo "[4] Настраиваю доступы..."
sudo chmod 700 /home/adminuser
sudo setfacl -m u:poweruser:rx /home/adminuser

########################################
# 5. symlink
########################################
echo "[5] Создаю symlink на /etc/mtab..."
sudo ln -snf /etc/mtab /home/poweruser/mtab-link
sudo chown poweruser:poweruser /home/poweruser/mtab-link

echo "--- ГОТОВО: все условия задания выполнены! ---"

EOF

ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$PUBLIC_IP" "chmod +x setup_users.sh"

##############################################
# 5. RUN SETUP_USERS.SH
##############################################

echo "=== 5) Выполняю setup_users.sh (интерактивный ввод пароля adminuser) ==="

ssh -t -i "$KEY_PATH" -o StrictHostKeyChecking=no "$REMOTE_USER@$PUBLIC_IP" "sudo ./setup_users.sh"

##############################################
# DONE
##############################################

echo "===================================="
echo "  ДЕПЛОЙ ЗАВЕРШЁН: ЗАДАНИЕ №4 ГОТОВО"
echo "===================================="
echo "Instance ID: $INSTANCE_ID"
echo "Public IP:   $PUBLIC_IP"
echo
echo "ssh -i $KEY_PATH ubuntu@$PUBLIC_IP"
