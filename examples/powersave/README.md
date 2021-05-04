
Example to use rpi-cookstrap to bootstrap an image with reduced
ressource usage:

* the "raspbian" plugin downloads and decompresses the
  latest raspbian lite image
* the "hostname" plugin sets the hostname to **RPI_HOSTNAME** configured
  in *bootstrap.cfg*
* the "wifi" plugin configures wireless networking using **RPI_WIFI_***
  settings in *bootstrap.cfg*
* the "ssh" plugin configures openssh by
  * adding the public key in **RPI_SSH_AUTHORIZE** to the
    ~/.ssh/authorized_keys file
* the "powersave" plugin tries to reduce resource usage (e.g. by
  disabling services and turning off unused hardware)
