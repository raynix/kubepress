(import 'wordpress.libsonnet') + 
{
    _config+:: {
        wordpress+: {
            name: 'dote',
            backup: 'ghcr.io/raynix/backup:v0.21',
            domain: 'dote.blog',
            cert: 'wordpress-dote-cert',
            volume_ip: '192.168.1.51',
            volume_path: '/var/nfs/k8s/dote.blog',
            volume_size: '10Gi',
            istio: 'magpie',
        },
    },

    sealed_secret: import 'ss.libsonnet',
}
