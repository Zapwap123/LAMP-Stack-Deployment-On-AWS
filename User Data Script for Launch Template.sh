#!/bin/bash

# Update and install all required packages
yum update -y
yum install -y unzip curl wget git httpd php php-fpm php-mysqlnd java-1.8.0-openjdk --allowerasing

# Enable & start Apache and PHP-FPM
systemctl enable httpd
systemctl start httpd
systemctl enable php-fpm
systemctl start php-fpm

# Ensure PHP-FPM log directory exists
mkdir -p /var/log/php-fpm
touch /var/log/php-fpm/error.log
chown apache:apache /var/log/php-fpm/error.log

# Deploy the LAMP App
cd /var/www/html
git clone https://github.com/mr-robertamoah/simple-lamp-stack.git
cp -r simple-lamp-stack/* .
cp simple-lamp-stack/.env.example .env

# Overwrite .env with DB credentials, substitute with your actual Database Details
cat <<EOF > .env
DB_HOST=<Your-DB-Host>
DB_NAME=<Your-DB-Name>
DB_USER=<Your-DB-User>
DB_PASSWORD=<Your-DB-Password>
EOF

# Set correct permissions
chown -R apache:apache /var/www/html
chmod 644 .env

# Clean up
rm -rf simple-lamp-stack

# Install CloudWatch Agent
cd /tmp
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create CloudWatch Agent config
tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json > /dev/null <<'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/lamp/apache/access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/lamp/apache/error",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/php-fpm/error.log",
            "log_group_name": "/lamp/php/error",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Enable and start SSM Agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
