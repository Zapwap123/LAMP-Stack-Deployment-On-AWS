#!/bin/bash
yum update -y
yum install -y httpd git php php-mysqlnd
systemctl enable httpd
systemctl start httpd

# Clone the app
cd /var/www/html
git clone https://github.com/mr-robertamoah/simple-lamp-stack.git

# Move the contents up
cp -r simple-lamp-stack/* .
cp simple-lamp-stack/.env.example .env  # Or create new one below

# Overwrite .env with correct credentials
# Substitute the placeholders with actual values of your database
cat <<EOF > .env
DB_HOST=<Your-DB-Host>
DB_NAME=<Your-DB-Name>
DB_USER=<Your-DB-User>
DB_PASSWORD=<Your-DB-Password>
EOF

# Set correct ownership and permissions
chown -R apache:apache /var/www/html
chmod 644 .env

# Optional: clean up
rm -rf simple-lamp-stack
