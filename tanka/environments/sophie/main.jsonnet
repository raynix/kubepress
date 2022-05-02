(import 'wordpress.libsonnet') +
{
    _config+:: {
        wordpress+: {
            name: 'sophie',
            domain: 'sophie.raynix.info',
            cert: 'wordpress-sophie-cert',
            volume_ip: '192.168.1.51',
            volume_path: '/var/nfs/k8s/sophix.me',
            volume_size: '10Gi',
            istio: 'magpie',
        },
    },

    sealed_secret: import 'ss.json',
}
