## Add the service Deamon
# Copy file 
Copy rssh.service file to /etc/systemd/system/
# Start the service
systemctl start rssh
# Automatically get it to start on boot
systemctl enable rssh
# Control the status of the service
systemctl -l status rssh
