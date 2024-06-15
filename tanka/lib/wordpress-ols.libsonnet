(import 'wordpress.libsonnet') + {
    _config:: {
        wordpress: {
            name: 'wp',
            replicas: 2,
            history: 3,
            image: 'docker.io/litespeedtech/openlitespeed:1.8.1-lsphp83',
            redis: 'redis:6.2.8-alpine3.17',
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
    local c = $._config.wordpress,
    local cm = $.core.v1.configMap,
    local deploy = $.apps.v1.deployment,
    local container = $.core.v1.container,
    local secret_ref = $.core.v1.envFromSource.secretRef,
    local volume_mount = $.core.v1.volumeMount,
    local volume = $.core.v1.volume,
    local volume_www = volume.fromPersistentVolumeClaim('var-www', 'wordpress'),
    local volume_gsa = volume.fromSecret('gcp-sa', 'backup-gcp-sa'),

    ols_config: cm.new('ols-httpd-config', { 'httpd_config.conf': importstr 'conf/ols_httpd_config.conf'}),
    ols_vh_config: cm.new('ols-vh-config', { 'vhconf.conf': importstr 'conf/ols_vhconf.conf'}),

    deploy:
        deploy.new('wordpress', c.replicas, [
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
            container.withPorts([ { name: 'http', containerPort: 8080, } ]) +
            container.withVolumeMounts([
                volume_mount.new(volume_www.name, '/var/www/vhosts/localhost/html'),
                volume_mount.new('ols-httpd-config-volume', '/usr/local/lsws/conf/httpd_config.conf') + volume_mount.withSubPath('httpd_config.conf'),
                volume_mount.new('ols-vh-config-volume', '/usr/local/lsws/conf/vhosts/Example/vhconf.conf')
            ]) +
            container.resources.withRequests({ cpu: '400m', memory: '400Mi' }) +
            myutil.readiness_probe('http') +
            myutil.liveness_probe('http'),
        ], { app: 'wordpress', 'domain': c.domain } ) +
        deploy.spec.withRevisionHistoryLimit(c.history)+
        deploy.spec.strategy.withType('RollingUpdate') +
        deploy.spec.strategy.rollingUpdate.withMaxSurge('50%') +
        deploy.spec.strategy.rollingUpdate.withMaxUnavailable(0) +
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
            volume.fromConfigMap('ols-httpd-config-volume', $.ols_config.metadata.name),
            volume.fromConfigMap('ols-vh-config-volume', $.ols_vh_config.metadata.name),
            volume_www,
        ]),
}
