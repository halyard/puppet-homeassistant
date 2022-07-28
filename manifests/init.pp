# @summary Configure HomeAssistant instance
#
# @param hostname sets the hostname for grafana
# @param datadir sets where the data is persisted
# @param tls_account sets the TLS account config
# @param tls_challengealias sets the alias for TLS cert
class homeassistant (
  String $hostname,
  String $datadir,
  String $tls_account,
  Optional[String] $tls_challengealias = undef,
) {
  file { ["${datadir}/config", "${datadir}/certs"]:
    ensure => directory,
  }

  -> acme::certificate { $hostname:
    reloadcmd      => '/usr/bin/systemctl restart container@homeassistant',
    keypath        => "${datadir}/certs/key",
    fullchainpath  => "${datadir}/certs/cert",
    account        => $tls_account,
    challengealias => $tls_challengealias,
  }

  -> docker::container { 'homeassistant':
    image => 'ghcr.io/home-assistant/home-assistant:stable',
    args  => [
      '--network=host',
      '--privileged',
      '-e TZ=Etc/UTC',
      "-v ${datadir}/config:/config"
      "-v ${datadir}/certs:/ssl",
      '--device /dev/ttyUSB0:/dev/ttyUSB0',
      '--device /dev/ttyUSB1:/dev/ttyUSB1',
    ],
    cmd   => '',
  }
}
