# policy-based-replication

## summary

Enabling DR at scale using Azure Policy.

### policy-1.0

- No ADE support (will come as non-compliant though)
- No unmanaged disks (won't appear)
- Features supported
  - **Regional DR with Target Zone**
    - Zone aware VMs in the source region will be protected to this zone in the target region.
    - Zone unaware VMs will be protected but wont be allotted any target zone.
  - **Regional DR without Target Zone**
    - Zone aware VMs will be ignored in this case
    - Zone unaware VMs will be protected (single instance)
  - **Zone to Zone replication**
    - Source and target region will be the same.
    - All VMs which are zone aware and not in the target zone will be considered (i.e. zone unaware VMs will be ignored)
      - Eg. Target zone – 3 and Source RG has VMs -
        - VM1 – zone 1
        - VM2 – zone 2
        - VM3 – zone 3
        - VM4 – zone unaware
      - VM1 and VM2 will be protected from their respective zones to zone 3.
  - **Proximity Placement Group**
    - PPG created by policy at runtime using following naming convention _\<source-ppg-name\>-asr_
    - Availability set and PPG combinations supported
  - **Availability Set**
    - Availability sets created by policy at runtime using following naming convention _\<source-avset-name\>-asr_
- Resources deployed
  - **Proximity Placement Groups** - only if source VM is in a PPG
  - **Availability Set** - only if source VM is in an AvSet
  - **Protected item** - only if eligible
- Resources that should be precreated
  - Vault RG + vault
  - ASR - Fabrics, Containers, Replication Policy and Container Mappings
  - Azure - Target RG, Cache SA, Recovery Network
