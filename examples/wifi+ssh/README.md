
Example to use rpi-cookstrap to bootstrap a minimal image:

* the "download_raspbian" plugin downloads and decompresses the
  latest raspbian lite image
* the "hostname" plugin sets the hostname to **RPI_HOSTNAME** configured
  in *bootstrap.cfg*
* the "wifi" plugin configures wireless networking using **RPI_WIFI_***
  settings in *bootstrap.cfg*
* the "ssh" plugin configures openssh by
  * copying the config file from *bootstrap-dist/etc/ssh/sshd_config* to
    */etc/ssh* and overwriting the shipped openssh config
  * generating a public key using ssh-keygen
  * adding the public key in **RPI_SSH_AUTHORIZE** to the
    *~/.ssh/authorized_keys* file