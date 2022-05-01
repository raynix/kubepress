(import 'k.libsonnet') + {
    _config:: {
        wordpress: {
            name: 'wp',
            image: 'wordpress:php7.4-fpm-alpine',
            nginx: 'nginx:1.20.1',
            backup: 'ghcr.io/raynix/backup:v0.21',
            domain: 'changeme.com',
            cert: 'changeme-cert',
            volume_ip: '10.0.0.0',
            volume_path: '/path/to/wordpress',
            volume_size: '10Gi',
            istio: 'magpie',
        }
    },

    local namespace = $.core.v1.namespace,
    local cm = $.core.v1.configMap,
    local c = $._config.wordpress,
    local cron = $.batch.v1beta1.cronJob,
    local pvc = $.core.v1.persistentVolumeClaim,
    local pv = $.core.v1.persistentVolume,
    local container = $.core.v1.container,
    local secret_ref = $.core.v1.envFromSource.secretRef,
    local volume_mount = $.core.v1.volumeMount,
    local volume = $.core.v1.volume,
    local gw = $.networking.v1beta1.gateway,
    local vs = $.networking.v1beta1.virtualService,
    local volume_www = volume.fromPersistentVolumeClaim('var-www', 'wordpress'),
    local volume_gsa = volume.fromSecret('gcp-sa', 'backup-gcp-sa'),

    namespace: namespace.new('wordpress-' + c.name)
    + namespace.mixin.metadata.withLabels({ "istio.io/rev": c.istio }),

    nginx_config: cm.new('nginx-config', { 'nginx.conf': importstr 'nginx.conf'}),
    php_config: cm.new('php-config', { 'php.ini': importstr 'php.ini'}),
    wp_config: cm.new('wordpress-nginx-config', { 'wordpress-nginx.conf': importstr 'wordpress-nginx.conf'}),

    wordpress_volume:
        pv.new('wordpress-' + c.name) +
        pv.spec.withCapacity({storage: c.volume_size}) +
        pv.spec.withAccessModes('ReadWriteMany') +
        pv.spec.withPersistentVolumeReclaimPolicy('Retain') +
        pv.spec.claimRef.withNamespace($.namespace.metadata.name) +
        pv.spec.claimRef.withName('wordpress') +
        pv.spec.withMountOptions(['hard', 'nfsvers=4.1']) +
        pv.spec.csi.withDriver('nfs.csi.k8s.io') +
        pv.spec.csi.withReadOnly(false) +
        pv.spec.csi.withVolumeHandle('wordpress-' + c.name + '-csi') +
        pv.spec.csi.withVolumeAttributes({ server: c.volume_ip, share: c.volume_path }),

    wordpress_volume_claim:
        pvc.new('wordpress') +
        pvc.spec.withAccessModes('ReadWriteMany') +
        pvc.spec.resources.withRequests({storage: c.volume_size}),

    backup_job: 
        cron.new('backup', '0 14 * * 0', [
            container.new('backup-tool', c.backup) +
            container.withCommand(['/bin/bash', '-c', |||
                until curl -fsI http://localhost:15021/healthz/ready; do
                    echo 'Waiting for Sidecar...'
                    sleep 1
                done
                /wordpress.sh $(DOMAIN) /wordpress /gcp/${SERVICE_ACCOUNT_KEY} ${BACKUP_BUCKET}
                curl -fsI -X POST http://localhost:15020/quitquitquit        
            |||]) +
            container.withEnvFrom([
                secret_ref.withName('wordpress-secret'),
                secret_ref.withName('backup-gcp-env'),
            ]) + 
            container.withVolumeMounts([
                volume_mount.new(volume_www.name, '/wordpress'),
                volume_mount.new(volume_gsa.name, '/gcp'),
            ]),
        ]) +
        cron.spec.jobTemplate.spec.template.spec.securityContext.withRunAsUser(65534) +
        cron.spec.jobTemplate.spec.template.spec.securityContext.withRunAsGroup(65534) +
        cron.spec.jobTemplate.spec.template.spec.withVolumes([volume_www, volume_gsa]),
    
    gateway:
        gw.new('wordpress-gateway') +
        gw.spec.withSelector({ istio: 'ingressgateway'}) +
        gw.spec.withServers([
            { 
                hosts: [c.domain],
                tls: {
                    mode: 'SIMPLE',
                    credentialName: c.cert,
                },
                ports: {
                    name: 'https-wp',
                    number: 443,
                    protocol: 'HTTPS',
                },
            },
            { 
                hosts: [c.domain],
                tls: {
                    httpsRedirect: true,
                },
                ports: {
                    name: 'http-wp',
                    number: 80,
                    protocol: 'HTTP',
                },
            },           
        ]),

    virtual_service:
        vs.new('wordpress-vs') +
        vs.spec.withGateways([$.gateway.metadata.name]) +
        vs.spec.withHosts([c.domain]) +
        vs.spec.withHttp([
            {
                route: {
                    destination: {
                        host: 'wordpress',
                    }
                }
            }
        ]),
}
