# @summary Configure HomeAssistant instance
#
# @param hostname sets the hostname for grafana
# @param datadir sets where the data is persisted
# @param dbdir sets the directory for sqlite storage
# @param tls_account sets the TLS account config
# @param tls_challengealias sets the alias for TLS cert
class homeassistant (
  String $hostname,
  String $datadir,
  String $dbdir,
  String $tls_account,
  Optional[String] $tls_challengealias = undef,
) {
  file { ["${datadir}/config", "${datadir}/certs", $dbdir]:
    ensure => directory,
  }

  -> acme::certificate { $hostname:
    reloadcmd      => '/usr/bin/systemctl restart container@homeassistant',
    keypath        => "${datadir}/certs/key",
    fullchainpath  => "${datadir}/certs/cert",
    account        => $tls_account,
    challengealias => $tls_challengealias,
  }

  -> firewall { '100 allow inbound 443 to homeassistant':
    dport  => 443,
    proto  => 'tcp',
    action => 'accept',
  }

  -> docker::container { 'homeassistant':
    image   => 'ghcr.io/home-assistant/home-assistant:stable',
    network => 'host',
    args    => [
      '--privileged',
      '-e TZ=Etc/UTC',
      "-v ${datadir}/config:/config",
      "-v ${datadir}/certs:/ssl",
      "-v ${dbdir}:/db"
      '--device /dev/ttyUSB0:/dev/ttyUSB0',
      '--device /dev/ttyUSB1:/dev/ttyUSB1',
    ],
    cmd     => '',
  }
}
