# WARNING: this file is generated, do not edit
# 01: /usr/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi/Apache/TestConfig.pm:898
# 02: /usr/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi/Apache/TestConfig.pm:916
# 03: /usr/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi/Apache/TestConfig.pm:1747
# 04: /usr/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi/Apache/TestRun.pm:502
# 05: /usr/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi/Apache/TestRun.pm:720
# 06: /usr/lib/perl5/site_perl/5.8.5/i386-linux-thread-multi/Apache/TestRun.pm:720
# 07: /usr/local/home/adelton/RayApp-1.164/httpd-tests/t/TEST:35

package apache_test_config;

sub new {
    bless( {
                 'verbose' => undef,
                 'hostport' => 'localhost.localdomain:8529',
                 'postamble' => [
                                  'TypesConfig "/etc/mime.types"',
                                  'Include "/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf/extra.conf"',
                                  ''
                                ],
                 'mpm' => 'prefork',
                 'inc' => [],
                 'APXS' => '/usr/sbin/apxs',
                 '_apxs' => {
                              'LIBEXECDIR' => '/usr/lib/httpd/modules',
                              'SYSCONFDIR' => '/etc/httpd/conf',
                              'TARGET' => 'httpd',
                              'BINDIR' => '/usr/bin',
                              'PREFIX' => '/etc/httpd',
                              'SBINDIR' => '/usr/sbin'
                            },
                 'save' => 1,
                 'vhosts' => {},
                 'httpd_basedir' => '/usr',
                 'server' => bless( {
                                      'run' => bless( {
                                                        'conf_opts' => {
                                                                         'verbose' => undef,
                                                                         'save' => 1,
                                                                         'maxclients' => 5
                                                                       },
                                                        'test_config' => $VAR1,
                                                        'tests' => [],
                                                        'opts' => {
                                                                    'breakpoint' => [],
                                                                    'postamble' => [],
                                                                    'preamble' => [],
                                                                    'bugreport' => 1,
                                                                    'req_args' => {},
                                                                    'header' => {}
                                                                  },
                                                        'argv' => [],
                                                        'server' => $VAR1->{'server'}
                                                      }, 'Apache::TestRun' ),
                                      'port_counter' => 8529,
                                      'mpm' => 'prefork',
                                      'version' => 'Apache/2.0.52',
                                      'rev' => '2',
                                      'name' => 'localhost.localdomain:8529',
                                      'config' => $VAR1
                                    }, 'Apache::TestServer' ),
                 'postamble_hooks' => [
                                        sub { "DUMMY" }
                                      ],
                 'inherit_config' => {
                                       'ServerRoot' => '/etc/httpd',
                                       'ServerAdmin' => 'support@skynet.cz',
                                       'TypesConfig' => '/etc/mime.types',
                                       'DocumentRoot' => '/usr/local/www',
                                       'LoadModule' => [
                                                         [
                                                           'status_module',
                                                           'modules/mod_status.so'
                                                         ],
                                                         [
                                                           'info_module',
                                                           'modules/mod_info.so'
                                                         ],
                                                         [
                                                           'access_module',
                                                           'modules/mod_access.so'
                                                         ],
                                                         [
                                                           'dir_module',
                                                           'modules/mod_dir.so'
                                                         ],
                                                         [
                                                           'mime_module',
                                                           'modules/mod_mime.so'
                                                         ],
                                                         [
                                                           'log_config_module',
                                                           'modules/mod_log_config.so'
                                                         ],
                                                         [
                                                           'setenvif_module',
                                                           'modules/mod_setenvif.so'
                                                         ],
                                                         [
                                                           'alias_module',
                                                           'modules/mod_alias.so'
                                                         ],
                                                         [
                                                           'env_module',
                                                           'modules/mod_env.so'
                                                         ],
                                                         [
                                                           'cgi_module',
                                                           'modules/mod_cgi.so'
                                                         ],
                                                         [
                                                           'auth_module',
                                                           'modules/mod_auth.so'
                                                         ],
                                                         [
                                                           'expires_module',
                                                           'modules/mod_expires.so'
                                                         ],
                                                         [
                                                           'perl_module',
                                                           'modules/mod_perl.so'
                                                         ],
                                                         [
                                                           'apreq_module',
                                                           '/usr/lib/httpd/modules/mod_apreq.so'
                                                         ],
                                                         [
                                                           'ssl_module',
                                                           'modules/mod_ssl.so'
                                                         ]
                                                       ]
                                     },
                 'cmodules_disabled' => {},
                 'preamble_hooks' => [
                                       sub { "DUMMY" }
                                     ],
                 'preamble' => [
                                 '<IfModule !mod_status.c>
    LoadModule status_module "/etc/httpd/modules/mod_status.so"
</IfModule>
',
                                 '<IfModule !mod_info.c>
    LoadModule info_module "/etc/httpd/modules/mod_info.so"
</IfModule>
',
                                 '<IfModule !mod_access.c>
    LoadModule access_module "/etc/httpd/modules/mod_access.so"
</IfModule>
',
                                 '<IfModule !mod_dir.c>
    LoadModule dir_module "/etc/httpd/modules/mod_dir.so"
</IfModule>
',
                                 '<IfModule !mod_mime.c>
    LoadModule mime_module "/etc/httpd/modules/mod_mime.so"
</IfModule>
',
                                 '<IfModule !mod_log_config.c>
    LoadModule log_config_module "/etc/httpd/modules/mod_log_config.so"
</IfModule>
',
                                 '<IfModule !mod_setenvif.c>
    LoadModule setenvif_module "/etc/httpd/modules/mod_setenvif.so"
</IfModule>
',
                                 '<IfModule !mod_alias.c>
    LoadModule alias_module "/etc/httpd/modules/mod_alias.so"
</IfModule>
',
                                 '<IfModule !mod_env.c>
    LoadModule env_module "/etc/httpd/modules/mod_env.so"
</IfModule>
',
                                 '<IfModule !mod_cgi.c>
    LoadModule cgi_module "/etc/httpd/modules/mod_cgi.so"
</IfModule>
',
                                 '<IfModule !mod_auth.c>
    LoadModule auth_module "/etc/httpd/modules/mod_auth.so"
</IfModule>
',
                                 '<IfModule !mod_expires.c>
    LoadModule expires_module "/etc/httpd/modules/mod_expires.so"
</IfModule>
',
                                 '<IfModule !mod_perl.c>
    LoadModule perl_module "/etc/httpd/modules/mod_perl.so"
</IfModule>
',
                                 '<IfModule !mod_apreq.c>
    LoadModule apreq_module "/usr/lib/httpd/modules/mod_apreq.so"
</IfModule>
',
                                 '<IfModule !mod_ssl.c>
    LoadModule ssl_module "/etc/httpd/modules/mod_ssl.so"
</IfModule>
',
                                 '<IfModule !mod_mime.c>
    LoadModule mime_module "/usr/lib/httpd/modules/mod_mime.so"
</IfModule>
',
                                 ''
                               ],
                 'vars' => {
                             'defines' => '',
                             'cgi_module_name' => 'mod_cgi',
                             'conf_dir' => '/etc/httpd/conf',
                             't_conf_file' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf/httpd.conf',
                             't_dir' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t',
                             'cgi_module' => 'mod_cgi.c',
                             'target' => 'httpd',
                             'thread_module' => 'worker.c',
                             'bindir' => '/usr/bin',
                             'user' => 'adelton',
                             'access_module_name' => 'mod_access',
                             'auth_module_name' => 'mod_auth',
                             'top_dir' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests',
                             'httpd_conf' => '/etc/httpd/conf/httpd.conf',
                             'httpd' => '/usr/sbin/httpd',
                             'scheme' => 'http',
                             'ssl_module_name' => 'mod_ssl',
                             'port' => 8529,
                             'sbindir' => '/usr/sbin',
                             't_conf' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf',
                             'servername' => 'localhost.localdomain',
                             'inherit_documentroot' => '/usr/local/www',
                             'proxy' => 'off',
                             'serveradmin' => 'support@skynet.cz',
                             'remote_addr' => '127.0.0.1',
                             'perlpod' => '/usr/lib/perl5/5.8.5/pod',
                             'sslcaorg' => 'asf',
                             'php_module_name' => 'sapi_apache2',
                             'maxclients_preset' => 5,
                             'php_module' => 'sapi_apache2.c',
                             'ssl_module' => 'mod_ssl.c',
                             'auth_module' => 'mod_auth.c',
                             'access_module' => 'mod_access.c',
                             't_logs' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/logs',
                             'minclients' => 1,
                             'maxclients' => 5,
                             'group' => 'adelton',
                             'apxs' => '/usr/sbin/apxs',
                             'maxclientsthreadedmpm' => 5,
                             'thread_module_name' => 'worker',
                             'documentroot' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/htdocs',
                             'serverroot' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t',
                             'sslca' => '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf/ssl/ca',
                             'perl' => '/usr/bin/perl',
                             'src_dir' => undef,
                             'proxyssl_url' => ''
                           },
                 'clean' => {
                              'files' => {
                                           '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf/httpd.conf' => 1,
                                           '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf/apache_test_config.pm' => 1,
                                           '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/logs/apache_runtime_status.sem' => 1,
                                           '/usr/local/home/adelton/RayApp-1.164/httpd-tests/t/conf/extra.conf' => 1
                                         }
                            },
                 'httpd_info' => {
                                   'BUILT' => 'Nov 11 2004 10:31:42',
                                   'MODULE_MAGIC_NUMBER_MINOR' => '9',
                                   'VERSION' => 'Apache/2.0.52',
                                   'MODULE_MAGIC_NUMBER' => '20020903:9',
                                   'MODULE_MAGIC_NUMBER_MAJOR' => '20020903'
                                 },
                 'modules' => {
                                'mod_env.c' => '/etc/httpd/modules/mod_env.so',
                                'mod_apreq.c' => '/usr/lib/httpd/modules/mod_apreq.so',
                                'core.c' => 1,
                                'http_core.c' => 1,
                                'mod_setenvif.c' => '/etc/httpd/modules/mod_setenvif.so',
                                'mod_access.c' => '/etc/httpd/modules/mod_access.so',
                                'mod_dir.c' => '/etc/httpd/modules/mod_dir.so',
                                'prefork.c' => 1,
                                'mod_cgi.c' => '/etc/httpd/modules/mod_cgi.so',
                                'mod_so.c' => 1,
                                'mod_perl.c' => '/etc/httpd/modules/mod_perl.so',
                                'mod_expires.c' => '/etc/httpd/modules/mod_expires.so',
                                'mod_alias.c' => '/etc/httpd/modules/mod_alias.so',
                                'mod_status.c' => '/etc/httpd/modules/mod_status.so',
                                'mod_auth.c' => '/etc/httpd/modules/mod_auth.so',
                                'mod_log_config.c' => '/etc/httpd/modules/mod_log_config.so',
                                'mod_ssl.c' => '/etc/httpd/modules/mod_ssl.so',
                                'mod_mime.c' => '/etc/httpd/modules/mod_mime.so',
                                'mod_info.c' => '/etc/httpd/modules/mod_info.so'
                              },
                 'httpd_defines' => {
                                      'SUEXEC_BIN' => '/usr/sbin/suexec',
                                      'APR_HAS_MMAP' => 1,
                                      'APR_HAS_OTHER_CHILD' => 1,
                                      'DEFAULT_PIDLOG' => 'logs/httpd.pid',
                                      'AP_TYPES_CONFIG_FILE' => 'conf/mime.types',
                                      'DEFAULT_SCOREBOARD' => 'logs/apache_runtime_status',
                                      'DEFAULT_LOCKFILE' => 'logs/accept.lock',
                                      'APR_USE_SYSVSEM_SERIALIZE' => 1,
                                      'APR_HAVE_IPV6 (IPv4-mapped addresses enabled)' => 1,
                                      'SINGLE_LISTEN_UNSERIALIZED_ACCEPT' => 1,
                                      'APACHE_MPM_DIR' => 'server/mpm/prefork',
                                      'DEFAULT_ERRORLOG' => 'logs/error_log',
                                      'APR_HAS_SENDFILE' => 1,
                                      'HTTPD_ROOT' => '/etc/httpd',
                                      'AP_HAVE_RELIABLE_PIPED_LOGS' => 1,
                                      'SERVER_CONFIG_FILE' => 'conf/httpd.conf',
                                      'APR_USE_PTHREAD_SERIALIZE' => 1
                                    }
               }, 'Apache::TestConfig' );
}

1;
