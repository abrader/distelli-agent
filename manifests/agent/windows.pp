# Install the Puppet Pipelines agent on Windows
#
# Do not use directly; use pipelines::agent.
class pipelines::agent::windows {
  $env = $facts['pipelines_env']

  if ! $puppet::agent::install_dir {
    $install_dir = "${env['ProgramFiles']}\\Distelli"
  } else {
    $install_dir = $puppet::agent::install_dir
  }

  if $puppet::agent::version {
    $download_url = "${puppet::agent::download_url}/${puppet::agent::version}.ps1"
  } else {
    $download_url = "${puppet::agent::download_url}.ps1"
  }
  $download_location = "${install_dir}/distelli-download.ps1"
  $download_cmd = "cmd.exe /c \"powershell -NoProfile -ExecutionPolicy Bypass -File \"${download_location}\"\""
  $agent_conf_file = "${env['SystemDrive']}\\distelli.yml"

  exec { "mkdir ${install_dir}":
    command => "cmd.exe /c \"md \"${install_dir}\"\"",
    path    => $facts['path'],
    onlyif  => "cmd.exe /c \"if exist \"${install_dir}\" exit 1",
  }
  file { $download_location:
    source  => $download_url,
    require => Exec["mkdir ${install_dir}"],
  }
  exec { 'pipelines::agent download':
    require     => Exec["mkdir ${install_dir}"],
    creates     => "${install_dir}/distelli.exe",
    path        => $facts['path'],
    environment => [
      "DISTELLI_INSTALL_DIR=${install_dir}",
    ],
    command     => $download_cmd,
  }
  if $pipelines::agent::start_agent {
    $distelli_yml_vars = {
      access_token => $pipelines::agent::access_token,
      secret_key => $pipelines::agent::secret_key,
      environments => $pipelines::agent::environments,
    }
    file { $agent_conf_file:
      ensure    => file,
      mode      => '0644',
      content   => epp('pipelines/distelli.yml.epp', $distelli_yml_vars),
      show_diff => false,
    }
    if $pipelines::agent::data_dir {
      $install_cmd = "cmd.exe /c \"distelli agent -data-dir \"${pipelines::agent::data_dir}\" install -readyml\" <nil"
    } else {
      $install_cmd = "cmd.exe /c \"distelli agent install -readyml\" <nil"
    }
    exec { 'pipelines::agent install':
      command     => $install_cmd,
      subscribe   => [
        Exec['pipelines::agent download'],
      ],
      refreshonly => true,
      path        => "${install_dir};${facts['path']}",
    }
  }
}
