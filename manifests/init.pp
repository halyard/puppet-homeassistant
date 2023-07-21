# @summary Configure HomeAssistant instance
#
# @param hostname sets the hostname for grafana
# @param datadir sets where the data is persisted
# @param aws_access_key_id sets the AWS key to use for Route53 challenge
# @param aws_secret_access_key sets the AWS secret key to use for the Route53 challenge
# @param email sets the contact address for the certificate
# @param backup_target sets the target repo for backups
# @param backup_watchdog sets the watchdog URL to confirm backups are working
# @param backup_password sets the encryption key for backup snapshots
# @param backup_environment sets the env vars to use for backups
# @param backup_rclone sets the config for an rclone backend
class homeassistant (
  String $hostname,
  String $datadir,
  String $aws_access_key_id,
  String $aws_secret_access_key,
  String $email,
  Optional[String] $backup_target = undef,
  Optional[String] $backup_watchdog = undef,
  Optional[String] $backup_password = undef,
  Optional[Hash[String, String]] $backup_environment = undef,
  Optional[String] $backup_rclone = undef,
) {
  $hook_script =  "#!/usr/bin/env bash
cp \$LEGO_CERT_PATH ${datadir}/certs/cert
cp \$LEGO_CERT_KEY_PATH ${datadir}/certs/cert
/usr/bin/systemctl restart container@homeassistant"

  file { [$datadir, "${datadir}/config", "${datadir}/certs"]:
    ensure => directory,
  }

  -> acme::certificate { $hostname:
    hook_script           => $hook_script,
    aws_access_key_id     => $aws_access_key_id,
    aws_secret_access_key => $aws_secret_access_key,
    email                 => $email,
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
