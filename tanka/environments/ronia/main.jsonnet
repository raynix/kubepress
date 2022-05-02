(import 'wordpress.libsonnet') +
{
    _config+:: {
        wordpress+: {
            name: 'ronia',
            domain: 'ronia.raynix.info',
            cert: 'wordpress-ronia-cert',
            volume_ip: '192.168.1.51',
            volume_path: '/var/nfs/k8s/ronia.me',
            volume_size: '10Gi',
            istio: 'magpie',
        },
    },

    sealed_secret: import 'ss.json',
}
