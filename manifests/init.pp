# @summary Configure HomeAssistant instance
#
# @param hostname sets the hostname for grafana
# @param datadir sets where the data is persisted
# @param tls_account sets the TLS account config
# @param tls_challengealias sets the alias for TLS cert
# @param backup_target sets the target repo for backups
# @param backup_watchdog sets the watchdog URL to confirm backups are working
# @param backup_password sets the encryption key for backup snapshots
# @param backup_environment sets the env vars to use for backups
# @param backup_rclone sets the config for an rclone backend
class homeassistant (
  String $hostname,
  String $datadir,
  String $tls_account,
  Optional[String] $tls_challengealias = undef,
  Optional[String] $backup_target = undef,
  Optional[String] $backup_watchdog = undef,
  Optional[String] $backup_password = undef,
  Optional[Hash[String, String]] $backup_environment = undef,
  Optional[String] $backup_rclone = undef,
) {
  file { [$datadir, "${datadir}/config", "${datadir}/certs"]:
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
      '--device /dev/ttyUSB0:/dev/ttyUSB0',
      '--device /dev/ttyUSB1:/dev/ttyUSB1',
    ],
    cmd     => '',
  }

  if $backup_rclone != undef {
    backup::repo { 'homeassistant':
      source        => "${datadir}/config",
      target        => $backup_target,
      watchdog_url  => $backup_watchdog,
      password      => $backup_password,
      environment   => $backup_environment,
      rclone_config => $backup_rclone,
    }
  }
}
