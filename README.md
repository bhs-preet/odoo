# Odoo Development Environment

This repository contains the Docker-based Odoo development environment for `oddev.boathire.com.au`.

## 🚀 Quick Start

### Prerequisites
- Ubuntu/Debian server with Docker support
- Domain pointing to your server
- Root access

### Installation

1. Clone this repository:
```bash
git clone https://github.com/bhs-preet/odoo.git
cd odoo
```

2. Copy the environment template:
```bash
cp .env.example .env
# Edit .env with your actual values
```

3. Run the installation script:
```bash
chmod +x install-odoo.sh
sudo ./install-odoo.sh
```

## 📁 Project Structure

```
├── addons/                 # Custom Odoo modules (your development goes here)
├── config/                 # Odoo configuration files
│   └── odoo.conf          # Main Odoo configuration
├── docker-compose.yml     # Docker container configuration
├── install-odoo.sh        # Automated installation script
├── .env.example          # Environment variables template
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

## 🔧 Development

### Adding Custom Modules

1. Create your module in the `addons/` directory:
```bash
mkdir addons/your_module_name
```

2. Create the basic module structure:
```
addons/your_module_name/
├── __init__.py
├── __manifest__.py
├── models/
├── views/
├── static/
└── security/
```

3. Restart Odoo container to load new modules:
```bash
cd /var/www/oddev
docker-compose restart odoo
```

### Accessing Odoo

- **URL**: https://oddev.boathire.com.au
- **Default Login**: admin / admin (change immediately)
- **Database Management**: Use master password from credentials file

## 🐳 Docker Commands

```bash
# View running containers
docker-compose ps

# View logs
docker-compose logs odoo
docker-compose logs db

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update Odoo image
docker-compose pull odoo
docker-compose up -d
```

## 🔒 Security

- Database passwords are auto-generated during installation
- Credentials are stored in `/var/www/oddev/CREDENTIALS.txt` (not in git)
- SSL certificates are automatically configured via Let's Encrypt
- Never commit `.env` or `CREDENTIALS.txt` files

## 📦 Backup & Restore

### Database Backup
```bash
docker-compose exec db pg_dump -U odoo postgres > backup.sql
```

### Database Restore
```bash
docker-compose exec -T db psql -U odoo postgres < backup.sql
```

## 🔄 Updates

### Updating Odoo
```bash
cd /var/www/oddev
docker-compose down
docker-compose pull odoo
docker-compose up -d
```

### Updating System
Re-run the installation script with updated configuration.

## 🛠️ Troubleshooting

### Check Service Status
```bash
docker-compose ps
docker-compose logs
```

### Reset Installation
```bash
# Edit install-odoo.sh and set MODE="remove"
sudo ./install-odoo.sh
# Then set MODE="install" and run again
sudo ./install-odoo.sh
```

## 📞 Support

For issues related to:
- **Odoo Core**: [Official Odoo Documentation](https://www.odoo.com/documentation)
- **Docker**: [Docker Documentation](https://docs.docker.com/)
- **This Setup**: Create an issue in this repository

## 📄 License

This project configuration is open source. Odoo itself is licensed under LGPL v3. 