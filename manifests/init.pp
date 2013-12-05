# Class: java
#
# This module manages the Java runtime package
#
# Parameters:
#
#  [*distribution*]
#    The java distribution to install. Can be one of "jdk" or "jre",
#    or other platform-specific options where there are multiple
#    implementations available (eg: OpenJDK vs Oracle JDK).
#
#
#  [*version*]
#    The version of java to install. By default, this module simply ensures
#    that java is present, and does not require a specific version.
#
#  [*package*]
#    The name of the java package. This is configurable in case a non-standard
#    java package is desired.
#
#  [*java_alternative*]
#    The name of the java alternative to use on Debian systems.
#    "update-java-alternatives -l" will show which choices are available.
#    If you specify a particular package, you will almost always also
#    want to specify which java_alternative to choose. If you set
#    this, you also need to set the path below.
#
#  [*java_alternative_path*]
#    The path to the "java" command on Debian systems. Since the
#    alternatives system makes it difficult to verify which
#    alternative is actually enabled, this is required to ensure the
#    correct JVM is enabled.
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
class java(
  $distribution          = 'jdk',
  $version               = 'present',
  $package               = undef,
  $java_alternative      = undef,
  $java_alternative_path = undef
) {
  include java::params

  case $::osfamily {
  default: {
    validate_re($version, 'present|installed|latest|^[._0-9a-zA-Z:-]+$')

    if has_key($java::params::java, $distribution) {
      $default_package_name     = $java::params::java[$distribution]['package']
      $default_alternative      = $java::params::java[$distribution]['alternative']
      $default_alternative_path = $java::params::java[$distribution]['alternative_path']
    } else {
      fail("Java distribution ${distribution} is not supported.")
    }

    $use_java_package_name = $package ? {
      default => $package,
      undef   => $default_package_name,
    }

    ## If $java_alternative is set, use that.
    ## Elsif the DEFAULT package is being used, then use $default_alternative.
    ## Else undef
    $use_java_alternative = $java_alternative ? {
      default => $java_alternative,
      undef   => $use_java_package_name ? {
        $default_package_name => $default_alternative,
        default               => undef,
      }
    }

    ## Same logic as $java_alternative above.
    $use_java_alternative_path = $java_alternative_path ? {
      default => $java_alternative_path,
      undef   => $use_java_package_name ? {
        $default_package_name => $default_alternative_path,
        default               => undef,
      }
    }

    anchor { 'java::begin:': }
    ->
    package { 'java':
      ensure => $version,
      name   => $use_java_package_name,
    }
    ->
    class { 'java::config': }
    -> anchor { 'java::end': }
  }
  'windows': {
    if $distribution == "JDK" {
	  fail("The JDK is currently unsupported for Windows via Puppet")
	}
	
    $bundleId = $java::params::java[$distribution]['package']

    $tempdir     = inline_template("<%= ENV['TEMP'] -%>")
    $systemdrive = inline_template("<%= ENV['SystemDrive'] -%>")

    $jre_file    = "${tempdir}\\java_install.exe"
    $bundle_url = "http://javadl.sun.com/webapps/download/AutoDL?BundleId=${bundleId}"

    exec { 'download_java':
      command => "powershell -NoProfile -ExecutionPolicy remotesigned -command \"(new-object net.webclient).DownloadFile('${bundle_url}', '${jre_file}')\"",
      path    => "${systemdrive}\\windows\\system32;${systemdrive}\\windows\\system32\\WindowsPowerShell\\v1.0",
      unless  => "cmd.exe /c If NOT EXIST ${jre_file} Exit 1",
    }

    exec { 'install_jre':
      command => "${jre_file} /s",
      path    => "${systemdrive}\\windows\\system32;${systemdrive}\\windows\\system32\\WindowsPowerShell\\v1.0",
      require => Exec[ 'download_java' ],
      unless  => "cmd.exe /c If NOT EXIST \"${systemdrive}\\Program Files\\Java\" Exit 1",
    }

    Exec['download_java'] -> Exec['install_jre']
  }
  }
}
