class functiontest {
  $_content = 'This is static content from class functiontest.'

  file { '/tmp/functiontest.txt':
    ensure  => 'present',
    owner   => 'nobody',
    group   => 'nogroup',
    mode    => '0666',
    content => envtestfunction($_content),
  }

}
