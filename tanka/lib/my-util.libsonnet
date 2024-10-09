(import "k.libsonnet") + {
  local vs = $.networking.v1beta1.virtualService,
  local gw = $.networking.v1beta1.gateway,
  local container = $.core.v1.container,
  local pvc = $.core.v1.persistentVolumeClaim,
  local pv = $.core.v1.persistentVolume,
  local sc = $.storage.v1.storageClass,

  virtual_service(service, domain, cert, gateway, https_port=443, http_port=80):
    vs.new(service.metadata.name) +
    vs.spec.withGateways([gateway.metadata.name]) +
    vs.spec.withHosts([domain]) +
    vs.spec.withHttp([
      {
        route: [
          {
            destination: { host: service.metadata.name },
          },
        ],
      },
    ]),

  gateway(name, hosts, cert_secret, default_selector={ istio: "ingressgateway" }):
    gw.new(name) +
    gw.spec.withSelector(default_selector) +
    gw.spec.withServers([
      {
        hosts: hosts,
        tls: {
          mode: "SIMPLE",
          credentialName: cert_secret,
        },
        port: {
          name: "https-" + name,
          number: 443,
          protocol: "HTTPS",
        },
      },
      {
        hosts: hosts,
        tls: {
          httpsRedirect: true,
        },
        port: {
          name: "http-" + name,
          number: 80,
          protocol: "HTTP",
        },
      },
    ]),

  readiness_probe(port, initial_delay_seconds=5, period_seconds=5):
    container.readinessProbe.tcpSocket.withPort(port) +
    container.readinessProbe.withInitialDelaySeconds(initial_delay_seconds) +
    container.readinessProbe.withPeriodSeconds(period_seconds),

  liveness_probe(port, initial_delay_seconds=15, period_seconds=15):
    container.livenessProbe.tcpSocket.withPort(port) +
    container.livenessProbe.withInitialDelaySeconds(initial_delay_seconds) +
    container.livenessProbe.withPeriodSeconds(period_seconds),

  static_volume(name, namespace): {
    local sv = self,
    volume_size:: "1Gi",
    volume_ip:: "10.0.0.1",
    volume_path:: "/mnt/data",

    wordpress_volume:
      pv.new('wordpress-' + name) +
      pv.spec.withCapacity({storage: sv.volume_size}) +
      pv.spec.withAccessModes('ReadWriteMany') +
      pv.spec.withPersistentVolumeReclaimPolicy('Retain') +
      pv.spec.claimRef.withNamespace(namespace) +
      pv.spec.claimRef.withName('wordpress') +
      pv.spec.withMountOptions(['hard', 'nfsvers=4.1']) +
      pv.spec.csi.withDriver('nfs.csi.k8s.io') +
      pv.spec.csi.withReadOnly(false) +
      pv.spec.csi.withVolumeHandle('wordpress-' + name + '-csi') +
      pv.spec.csi.withVolumeAttributes({ server: sv.volume_ip, share: sv.volume_path }),

    wordpress_volume_claim:
      pvc.new('wordpress') +
      pvc.spec.withAccessModes('ReadWriteMany') +
      pvc.spec.resources.withRequests({storage: sv.volume_size}),
  }
}
