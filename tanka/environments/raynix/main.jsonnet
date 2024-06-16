(import 'wordpress.libsonnet') +
{
    _config+:: {
        wordpress+: {
            name: 'raynix',
            replicas: 2,
            domain: 'raynix.info',
            cert: 'wordpress-raynix-cert',
            volume_ip: '192.168.1.51',
            volume_path: '/var/nfs/k8s/raynix.info',
            volume_size: '10Gi',
            istio: true,
        },
    },

    sealed_secret: import 'ss.json',
}
