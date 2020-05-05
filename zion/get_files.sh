#!/bin/bash

SRCHOST="zion.matrix.lab"

mkdir -p etc/dhcp var/lib/tftpboot/efi/ /etc/httpd/conf.d/

rsync -tugrpolvv ${SRCHOST}:/etc/dhcp/*.conf etc/dhcp/
rsync -tugrpolvv ${SRCHOST}:/var/lib/tftpboot/efi/grub* var/lib/tftpboot/efi/
rsync -tugrpovlvv ${SRCHOST}:/etc/httpd/conf.d/*.conf etc/httpd/conf.d/
