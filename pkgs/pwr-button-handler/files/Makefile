
all:
	gcc -O2 -DNDEBUG -o pwr_button_handler pwr-button-handler.c

clean:
	-rm pwr_button_handler

install:
	install -m 0755 pwr_button_handler ${DESTDIR}/usr/bin
	install -m 644 pwr-button-handler.service ${DESTDIR}/lib/systemd/system
	#systemctl enable pwr-button-handler.service
