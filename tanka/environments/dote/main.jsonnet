(import 'wordpress.libsonnet') +
{
    _config+:: {
        wordpress+: {
            name: 'dote',
            domain: 'dote.blog',
            volume_ip: '192.168.1.51',
            volume_path: '/var/nfs/k8s/dote.blog',
            volume_size: '10Gi',
            istio: true,
        },
    },

    sealed_secret: import 'ss.json',
}
