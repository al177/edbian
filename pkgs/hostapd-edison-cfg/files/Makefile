
clean:
all:
	echo "do nothing"

install:
	install -v -d /etc/hostapd
	install -m 0644 hostapd.conf-sane /etc/hostapd/hostapd.conf
	install -m 0644 udhcpd-for-hostapd.conf /etc/hostapd
	install -v -d /lib/systemd/system
	install -m 0644 udhcpd-for-hostapd.service /lib/systemd/system
	install -m 0644 hostapd.service /lib/systemd/system
	systemctl enable pwr-button-handler.service
