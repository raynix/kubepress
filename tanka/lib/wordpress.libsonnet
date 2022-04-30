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
    local container = $.core.v1.container,
    local secret_ref = $.core.v1.envFromSource.secretRef,
    local volume_mount = $.core.v1.volumeMount,
    local volume = $.core.v1.volume,
    local volume_www = volume.fromPersistentVolumeClaim('var-www', 'wordpress'),
    local volume_gsa = volume.fromSecret('gcp-sa', 'backup-gcp-sa'),

    namespace: namespace.new('wordpress-' + c.name)
    + namespace.mixin.metadata.withLabels({ "istio.io/rev": c.istio }),

    nginx_config: cm.new('nginx-config', { 'nginx.conf': importstr 'nginx.conf'}),
    php_config: cm.new('php-config', { 'php.ini': importstr 'php.ini'}),
    wp_config: cm.new('wordpress-nginx-config', { 'wordpress-nginx.conf': importstr 'wordpress-nginx.conf'}),

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
}
