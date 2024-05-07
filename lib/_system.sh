#!/bin/bash
# 
# Gerenciamento do sistema

#######################################
# Cria usuário
# Argumentos:
#   Nenhum
#######################################
system_create_user() {
  print_banner
  printf "${WHITE} 💻 Agora, vamos criar o usuário para a instância...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo useradd -m -p $(openssl passwd -crypt ${mysql_root_password}) -s /bin/bash -G wheel deploy
}

#######################################
# Clona repositórios usando git
# Argumentos:
#   Nenhum
#######################################
system_git_clone() {
  print_banner
  printf "${WHITE} 💻 Fazendo download do código Whaticket...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo -u deploy git clone ${link_git} /home/deploy/${instancia_add}/
}

#######################################
# Atualiza sistema
# Argumentos:
#   Nenhum
#######################################
system_update() {
  print_banner
  printf "${WHITE} 💻 Vamos atualizar o sistema Whaticket...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo yum -y update
  sudo yum -y install epel-release
  sudo yum -y install libxshmfence-devel libgbm-devel wget unzip fontconfig gconf-service \
    libasound2 atk cairo cups dbus expat fontconfig glib2 gtk3 nspr pango \
    libstdc++ libX11 libX11-xcb libxcb libXcomposite libXcursor libXdamage \
    libXext libXfixes libXi libXrandr libXrender libXtst ca-certificates \
    liberation-fonts libappindicator nss lsb-release xdg-utils
}

#######################################
# Deleta sistema
# Argumentos:
#   Nenhum
#######################################
deletar_tudo() {
  print_banner
  printf "${WHITE} 💻 Vamos deletar o Whaticket...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo docker container rm redis-${empresa_delete} --force
  sudo rm -rf /etc/nginx/sites-enabled/${empresa_delete}-frontend
  sudo rm -rf /etc/nginx/sites-enabled/${empresa_delete}-backend  
  sudo rm -rf /etc/nginx/sites-available/${empresa_delete}-frontend
  sudo rm -rf /etc/nginx/sites-available/${empresa_delete}-backend
  
  sudo -u postgres dropuser ${empresa_delete}
  sudo -u postgres dropdb ${empresa_delete}

  sudo -u deploy rm -rf /home/deploy/${empresa_delete}
  sudo pm2 delete ${empresa_delete}-frontend ${empresa_delete}-backend
  sudo pm2 save

  print_banner
  printf "${WHITE} 💻 Remoção da Instancia/Empresa ${empresa_delete} realizado com sucesso ...${GRAY_LIGHT}"
  printf "\n\n"
}

#######################################
# Bloqueia sistema
# Argumentos:
#   Nenhum
#######################################
configurar_bloqueio() {
  print_banner
  printf "${WHITE} 💻 Vamos bloquear o Whaticket...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo -u deploy pm2 stop ${empresa_bloquear}-backend
  sudo -u deploy pm2 save

  print_banner
  printf "${WHITE} 💻 Bloqueio da Instancia/Empresa ${empresa_bloquear} realizado com sucesso ...${GRAY_LIGHT}"
  printf "\n\n"
}

#######################################
# Desbloqueia sistema
# Argumentos:
#   Nenhum
#######################################
configurar_desbloqueio() {
  print_banner
  printf "${WHITE} 💻 Vamos Desbloquear o Whaticket...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo -u deploy pm2 start ${empresa_bloquear}-backend
  sudo -u deploy pm2 save

  print_banner
  printf "${WHITE} 💻 Desbloqueio da Instancia/Empresa ${empresa_desbloquear} realizado com sucesso ...${GRAY_LIGHT}"
  printf "\n\n"
}

#######################################
# Altera domínio do sistema
# Argumentos:
#   Nenhum
#######################################
configurar_dominio() {
  print_banner
  printf "${WHITE} 💻 Vamos Alterar os Domínios do Whaticket...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo rm -rf /etc/nginx/sites-enabled/${empresa_dominio}-frontend
  sudo rm -rf /etc/nginx/sites-enabled/${empresa_dominio}-backend  
  sudo rm -rf /etc/nginx/sites-available/${empresa_dominio}-frontend
  sudo rm -rf /etc/nginx/sites-available/${empresa_dominio}-backend
  
  sudo -u deploy sed -i "1c\REACT_APP_BACKEND_URL=https://${alter_backend_url}" /home/deploy/${empresa_dominio}/frontend/.env
  sudo -u deploy sed -i "2c\BACKEND_URL=https://${alter_backend_url}" /home/deploy/${empresa_dominio}/backend/.env
  sudo -u deploy sed -i "3c\FRONTEND_URL=https://${alter_frontend_url}" /home/deploy/${empresa_dominio}/backend/.env 

  backend_hostname=$(echo "${alter_backend_url/https:\/\/}")
  sudo su - root -c "cat > /etc/nginx/sites-available/${empresa_dominio}-backend << 'END'
server {
  server_name $backend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${alter_backend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
END"
  ln -s /etc/nginx/sites-available/${empresa_dominio}-backend /etc/nginx/sites-enabled

  frontend_hostname=$(echo "${alter_frontend_url/https:\/\/}")
  sudo su - root -c "cat > /etc/nginx/sites-available/${empresa_dominio}-frontend << 'END'
server {
  server_name $frontend_hostname;
  location / {
    proxy_pass http://127.0.0.1:${alter_frontend_port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
END"
  ln -s /etc/nginx/sites-available/${empresa_dominio}-frontend /etc/nginx/sites-enabled

  service nginx restart

  backend_domain=$(echo "${backend_url/https:\/\/}")
  frontend_domain=$(echo "${frontend_url/https:\/\/}")

  certbot -m $deploy_email \
          --nginx \
          --agree-tos \
          --non-interactive \
          --domains $backend_domain,$frontend_domain

  print_banner
  printf "${WHITE} 💻 Alteração de domínio da Instancia/Empresa ${empresa_dominio} realizado com sucesso ...${GRAY_LIGHT}"
  printf "\n\n"
}

#######################################
# Instala node
# Argumentos:
#   Nenhum
#######################################
system_node_install() {
  print_banner
  printf "${WHITE} 💻 Instalando nodejs...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  curl -fsSL https://rpm.nodesource.com/setup_16.x | sudo bash -
  sudo yum -y install nodejs
  npm install -g npm@latest
  sudo sh -c 'echo -e "[pgdg${lsb_release -rs}]\\nname=PostgreSQL $releasever - $basearch\\nbaseurl=https://download.postgresql.org/pub/repos/yum/reporpms/EL-\$releasever-\$basearch\\nenabled=1\\ngpgcheck=0" > /etc/yum.repos.d/pgdg.repo'
  sudo yum -y install postgresql-server
  sudo systemctl enable postgresql
  sudo systemctl start postgresql

  timedatectl set-timezone America/Sao_Paulo
}

#######################################
# Instala docker
# Argumentos:
#   Nenhum
#######################################
system_docker_install() {
  print_banner
  printf "${WHITE} 💻 Instalando docker...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo yum -y install yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum -y install docker-ce docker-ce-cli containerd.io
  sudo systemctl start docker
  sudo systemctl enable docker
}

#######################################
# Instala dependências do Puppeteer
# Argumentos:
#   Nenhum
#######################################
system_puppeteer_dependencies() {
  print_banner
  printf "${WHITE} 💻 Instalando dependências do puppeteer...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo yum -y install libXcomposite libXcursor libXi libXtst libXrandr \
    alsa-lib atk gtk3 ipa-gothic-fonts xorg-x11-fonts-100dpi \
    xorg-x11-fonts-75dpi xorg-x11-utils xorg-x11-fonts-cyrillic \
    xorg-x11-fonts-Type1 xorg-x11-fonts-misc
}

#######################################
# Instala pm2
# Argumentos:
#   Nenhum
#######################################
system_pm2_install() {
  print_banner
  printf "${WHITE} 💻 Instalando pm2...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo npm install -g pm2
}

#######################################
# Instala snapd
# Argumentos:
#   Nenhum
#######################################
system_snapd_install() {
  print_banner
  printf "${WHITE} 💻 Instalando snapd...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo yum -y install epel-release
  sudo yum -y install snapd
  sudo systemctl enable --now snapd.socket
  sudo ln -s /var/lib/snapd/snap /snap
  sudo systemctl start snapd
}

#######################################
# Instala certbot
# Argumentos:
#   Nenhum
#######################################
system_certbot_install() {
  print_banner
  printf "${WHITE} 💻 Instalando certbot...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo yum -y remove certbot
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
}

#######################################
# Instala nginx
# Argumentos:
#   Nenhum
#######################################
system_nginx_install() {
  print_banner
  printf "${WHITE} 💻 Instalando nginx...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo yum -y install nginx
  sudo rm /etc/nginx/conf.d/default.conf
}

#######################################
# Reinicia nginx
# Argumentos:
#   Nenhum
#######################################
system_nginx_restart() {
  print_banner
  printf "${WHITE} 💻 Reiniciando nginx...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo systemctl restart nginx
}

#######################################
# Configura nginx.conf
# Argumentos:
#   Nenhum
#######################################
system_nginx_conf() {
  print_banner
  printf "${WHITE} 💻 Configurando nginx...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  sudo su - root -c "cat > /etc/nginx/conf.d/deploy.conf << 'END'
client_max_body_size 100M;
END"
}

#######################################
# Configuração para nginx.conf
# Argumentos:
#   Nenhum
#######################################
system_certbot_setup() {
  print_banner
  printf "${WHITE} 💻 Configurando certbot...${GRAY_LIGHT}"
  printf "\n\n"

  sleep 2

  backend_domain=$(echo "${backend_url/https:\/\/}")
  frontend_domain=$(echo "${frontend_url/https:\/\/}")

  sudo certbot -m $deploy_email \
          --nginx \
          --agree-tos \
          --non-interactive \
          --domains $backend_domain,$frontend_domain
}

# Agora você pode chamar as funções conforme necessário.
