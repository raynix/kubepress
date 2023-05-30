{
  local d = (import 'doc-util/main.libsonnet'),
  '#':: d.pkg(name='persistentVolumeClaimStatus', url='', help='"PersistentVolumeClaimStatus is the current status of a persistent volume claim."'),
  '#withAccessModes':: d.fn(help='"accessModes contains the actual access modes the volume backing the PVC has. More info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#access-modes-1"', args=[d.arg(name='accessModes', type=d.T.array)]),
  withAccessModes(accessModes): { accessModes: if std.isArray(v=accessModes) then accessModes else [accessModes] },
  '#withAccessModesMixin':: d.fn(help='"accessModes contains the actual access modes the volume backing the PVC has. More info: https://kubernetes.io/docs/concepts/storage/persistent-volumes#access-modes-1"\n\n**Note:** This function appends passed data to existing values', args=[d.arg(name='accessModes', type=d.T.array)]),
  withAccessModesMixin(accessModes): { accessModes+: if std.isArray(v=accessModes) then accessModes else [accessModes] },
  '#withAllocatedResources':: d.fn(help='"allocatedResources is the storage resource within AllocatedResources tracks the capacity allocated to a PVC. It may be larger than the actual capacity when a volume expansion operation is requested. For storage quota, the larger value from allocatedResources and PVC.spec.resources is used. If allocatedResources is not set, PVC.spec.resources alone is used for quota calculation. If a volume expansion capacity request is lowered, allocatedResources is only lowered if there are no expansion operations in progress and if the actual volume capacity is equal or lower than the requested capacity. This is an alpha field and requires enabling RecoverVolumeExpansionFailure feature."', args=[d.arg(name='allocatedResources', type=d.T.object)]),
  withAllocatedResources(allocatedResources): { allocatedResources: allocatedResources },
  '#withAllocatedResourcesMixin':: d.fn(help='"allocatedResources is the storage resource within AllocatedResources tracks the capacity allocated to a PVC. It may be larger than the actual capacity when a volume expansion operation is requested. For storage quota, the larger value from allocatedResources and PVC.spec.resources is used. If allocatedResources is not set, PVC.spec.resources alone is used for quota calculation. If a volume expansion capacity request is lowered, allocatedResources is only lowered if there are no expansion operations in progress and if the actual volume capacity is equal or lower than the requested capacity. This is an alpha field and requires enabling RecoverVolumeExpansionFailure feature."\n\n**Note:** This function appends passed data to existing values', args=[d.arg(name='allocatedResources', type=d.T.object)]),
  withAllocatedResourcesMixin(allocatedResources): { allocatedResources+: allocatedResources },
  '#withCapacity':: d.fn(help='"capacity represents the actual resources of the underlying volume."', args=[d.arg(name='capacity', type=d.T.object)]),
  withCapacity(capacity): { capacity: capacity },
  '#withCapacityMixin':: d.fn(help='"capacity represents the actual resources of the underlying volume."\n\n**Note:** This function appends passed data to existing values', args=[d.arg(name='capacity', type=d.T.object)]),
  withCapacityMixin(capacity): { capacity+: capacity },
  '#withConditions':: d.fn(help="\"conditions is the current Condition of persistent volume claim. If underlying persistent volume is being resized then the Condition will be set to 'ResizeStarted'.\"", args=[d.arg(name='conditions', type=d.T.array)]),
  withConditions(conditions): { conditions: if std.isArray(v=conditions) then conditions else [conditions] },
  '#withConditionsMixin':: d.fn(help="\"conditions is the current Condition of persistent volume claim. If underlying persistent volume is being resized then the Condition will be set to 'ResizeStarted'.\"\n\n**Note:** This function appends passed data to existing values", args=[d.arg(name='conditions', type=d.T.array)]),
  withConditionsMixin(conditions): { conditions+: if std.isArray(v=conditions) then conditions else [conditions] },
  '#withPhase':: d.fn(help='"phase represents the current phase of PersistentVolumeClaim.\\n\\n"', args=[d.arg(name='phase', type=d.T.string)]),
  withPhase(phase): { phase: phase },
  '#withResizeStatus':: d.fn(help='"resizeStatus stores status of resize operation. ResizeStatus is not set by default but when expansion is complete resizeStatus is set to empty string by resize controller or kubelet. This is an alpha field and requires enabling RecoverVolumeExpansionFailure feature."', args=[d.arg(name='resizeStatus', type=d.T.string)]),
  withResizeStatus(resizeStatus): { resizeStatus: resizeStatus },
  '#mixin': 'ignore',
  mixin: self,
}
