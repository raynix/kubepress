local tk = import 'tanka-util/main.libsonnet';
local wp = import 'wordpress.libsonnet';

function(domain, name='') {
  local app_name = if std.isEmpty(name) then std.strReplace(domain, '.', '-') else name,

  data:: wp {
    _config+:: {
      wordpress+: {
        name: app_name,
        replicas: 2,
        domain: domain,
        volume_ip: '192.168.1.51',
        volume_path: '/var/nfs/k8s/raynix.info',
        volume_size: '10Gi',
        istio: true,
      },
    },

    //sealed_secret: import 'ss.json',
  },

  env:: tk.environment.new(
    name='environments/' + app_name,
    namespace='wordpress-' + app_name,
    apiserver='',
  ) + tk.environment.withData($.data),

  envs: {
    [app_name]: $.env,
  },
}
