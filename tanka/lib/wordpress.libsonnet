(import 'k.libsonnet') + {
    _config:: {
        wordpress: {
            name: 'wp',
            replicas: 2,
            history: 3,
            image: 'wordpress:php7.4-fpm-alpine',
            nginx: 'nginx:1.20.1',
            redis: 'redis:4.0',
            backup: 'ghcr.io/raynix/backup:v0.37',
            domain: 'changeme.com',
            cert: 'changeme-cert',
            volume_ip: '10.0.0.0',
            volume_path: '/path/to/wordpress',
            volume_size: '10Gi',
            istio: 'magpie',
        }
    },

    local myutil = import 'my-util.libsonnet',
    local namespace = $.core.v1.namespace,
    local cm = $.core.v1.configMap,
    local c = $._config.wordpress,
    local cron = $.batch.v1beta1.cronJob,
    local pvc = $.core.v1.persistentVolumeClaim,
    local pv = $.core.v1.persistentVolume,
    local deploy = $.apps.v1.deployment,
    local svc = $.core.v1.service,
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

    nginx_config: cm.new('nginx-config', { 'nginx.conf': importstr 'conf/nginx.conf'}),
    php_config: cm.new('php-config', { 'php.ini': importstr 'conf/php.ini'}),
    wp_config: cm.new('wordpress-nginx-config', { 'wordpress-nginx.conf': importstr 'conf/wordpress-nginx.conf'}),

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
        cron.spec.jobTemplate.spec.template.spec.withRestartPolicy('Never') +
        cron.spec.jobTemplate.spec.template.spec.securityContext.withRunAsUser(65534) +
        cron.spec.jobTemplate.spec.template.spec.securityContext.withRunAsGroup(65534) +
        cron.spec.jobTemplate.spec.template.spec.withVolumes([volume_www, volume_gsa]),

    deploy:
        deploy.new('wordpress', c.replicas, [
            # wordpress-php-fpm container
            container.new('wordpress', c.image) +
            container.withEnvFrom([
                secret_ref.withName('wordpress-secret'),
            ]) +
            container.withEnv([
                {
                    name: 'WORDPRESS_TABLE_PREFIX',
                    value: 'wp_',
                }
            ]) +
            container.withPorts([ { name: 'fpm', containerPort: 9000, } ]) +
            container.withVolumeMounts([
                volume_mount.new('php-config-volume', '/usr/local/etc/php/php.ini') +
                volume_mount.withSubPath('php.ini'),
                volume_mount.new(volume_www.name, '/var/www/html'),
            ]) +
            container.resources.withRequests({ cpu: '400m', memory: '400Mi' }) +
            container.readinessProbe.tcpSocket.withPort('fpm') +
            container.readinessProbe.withInitialDelaySeconds(5) +
            container.readinessProbe.withPeriodSeconds(10) +
            container.livenessProbe.tcpSocket.withPort('fpm') +
            container.livenessProbe.withInitialDelaySeconds(15) +
            container.livenessProbe.withPeriodSeconds(15),
            # nginx container
            container.new('nginx', c.nginx) +
            container.withPorts([ { name: 'http', containerPort: 8080 }]) +
            container.withVolumeMounts([
                volume_mount.new('wordpress-nginx-config-volume', '/etc/nginx/conf.d'),
                volume_mount.new('nginx-config-volume', '/etc/nginx/nginx.conf') +
                volume_mount.withSubPath('nginx.conf'),
                volume_mount.new(volume_www.name, '/var/www/html'),
            ]) +
            container.resources.withRequests({ cpu: '100m', memory: '100Mi' })+
            container.readinessProbe.tcpSocket.withPort('http') +
            container.readinessProbe.withInitialDelaySeconds(5) +
            container.readinessProbe.withPeriodSeconds(10) +
            container.livenessProbe.tcpSocket.withPort('http') +
            container.livenessProbe.withInitialDelaySeconds(15) +
            container.livenessProbe.withPeriodSeconds(15)
        ], { app: 'wordpress', 'domain': c.domain } ) +
        deploy.spec.withRevisionHistoryLimit(c.history)+
        deploy.spec.strategy.withType('RollingUpdate') +
        deploy.spec.strategy.rollingUpdate.withMaxSurge('50%') +
        deploy.spec.strategy.rollingUpdate.withMaxUnavailable(0) +
        deploy.spec.template.spec.securityContext.withRunAsUser(65534) +
        deploy.spec.template.spec.securityContext.withRunAsGroup(65534) +
        deploy.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution([
            {
                weight: 100,
                podAffinityTerm: {
                    labelSelector: {
                        matchExpressions: [
                            {
                                key: 'app',
                                operator: 'In',
                                values: ['wordpress']
                            },
                            {
                                key: 'domain',
                                operator: 'In',
                                values: [c.domain]
                            },
                        ],
                    },
                    topologyKey: "kubernetes.io/hostname",
                }
            }
        ]) +
        deploy.spec.template.spec.withVolumes([
            volume.fromConfigMap('nginx-config-volume', $.nginx_config.metadata.name),
            volume.fromConfigMap('wordpress-nginx-config-volume', $.wp_config.metadata.name),
            volume.fromConfigMap('php-config-volume', $.php_config.metadata.name),
            volume_www,
        ]),

    service:
        svc.new($.deploy.metadata.name, $.deploy.spec.selector.matchLabels, [
            { name: 'http-wp', port: 8080, targetPort: 8080 }
        ]),

    gateway: myutil.gateway($.deploy.metadata.name, [c.domain], c.cert),
    virtual_service: myutil.virtual_service($.service, c.domain, c.cert, gateway=$.gateway),

    redis_deploy:
        deploy.new('redis', 1, [
            container.new('redis', c.redis) +
            container.withPorts([ { name: 'redis', containerPort: 6379, } ]) +
            container.resources.withRequests({ cpu: '100m', memory: '200Mi' }),
        ], { app: 'redis' }),

    redis_service:
        svc.new($.redis_deploy.metadata.name, $.redis_deploy.spec.selector.matchLabels, [
            { name: 'tcp-redis', port: 6379, targetPort: 6379 }
        ]),

}
