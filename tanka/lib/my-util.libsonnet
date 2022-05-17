(import 'k.libsonnet') + {
    virtual_service(service, domain, cert, gateway, https_port=443, http_port=80)::
        local vs = $.networking.v1beta1.virtualService;
        vs.new(service.metadata.name) +
        vs.spec.withGateways([gateway.metadata.name]) +
        vs.spec.withHosts([domain]) +
        vs.spec.withHttp([
            {
                route: [
                    {
                        destination: { host: service.metadata.name, },
                    },
                ],
            },
        ]),

    gateway(name, hosts, cert_secret, default_selector={ istio: 'ingressgatewway'})::
        local gw = $.networking.v1beta1.gateway;
        gw.new(name) +
        gw.spec.withSelector(default_selector) +
        gw.spec.withServers([
            {
                hosts: hosts,
                tls: {
                    mode: 'SIMPLE',
                    credentialName: cert_secret,
                },
                port: {
                    name: 'https-' + name,
                    number: 443,
                    protocol: 'HTTPS',
                },
            },
            {
                hosts: hosts,
                tls: {
                    httpsRedirect: true,
                },
                port: {
                    name: 'http-' + name,
                    number: 80,
                    protocol: 'HTTP',
                },
            },
        ]),
}
