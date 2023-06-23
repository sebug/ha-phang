sudo dnf -y install haproxy
sudo systemctl start haproxy
sudo systemctl enable haproxy
curl https://raw.githubusercontent.com/sebug/ha-phang/main/haproxy.cfg | sudo tee /etc/haproxy/haproxy.cfg
sudo ls -l /etc/haproxy/haproxy.cfg
sudo sed -i '/"imudp/s/^#//g' /etc/rsyslog.conf
echo -e "local2.=info\t/var/log/haproxy-access.log" | sudo tee  /etc/rsyslog.d/haproxy.conf
echo -e "local2.notice\t/var/log/haproxy-info.log" | sudo tee -a /etc/rsyslog.d/haproxy.conf
sudo systemctl start rsyslog
sudo systemctl enable rsyslog
sudo systemctl restart haproxy
