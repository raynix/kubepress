(import 'k.libsonnet') + {
    _config:: {
        wordpress: {
            name: 'wp',
            image: 'wordpress:php7.4-fpm-alpine',
            nginx: 'nginx:1.20.1',
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

    namespace: namespace.new('wordpress-' + c.name)
    + namespace.mixin.metadata.withLabels({ "istio.io/rev": c.istio }),

    nginx_config: cm.new('nginx-config', { 'nginx.conf': importstr 'nginx.conf'}),
    php_config: cm.new('php-config', { 'php.ini': importstr 'php.ini'}),
    wp_config: cm.new('wordpress-nginx-config', { 'wordpress-nginx.conf': importstr 'wordpress-nginx.conf'}),
    
}

