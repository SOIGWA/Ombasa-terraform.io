#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user-data script execution..."

for i in {1..12}; do
  apt-get update -y && break
  echo "apt-get update failed, attempt $i/12, retrying in 15s..."
  sleep 15
done

apt-get install -y nginx

cat > /var/www/html/index.html <<HTML
<h1>Hello, World V2</h1>
<p>The database is located at: <b>${db_address}</b></p>
<p>The database is listening on port: <b>${db_port}</b></p>
HTML

systemctl enable nginx
systemctl restart nginx

echo "nginx started successfully"