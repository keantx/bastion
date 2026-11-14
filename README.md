## Bastion
Bastion host image for the platform, built with Packer on Azure.

### This is heavily redacted version of the bastion VMSS image IaC I personally maintain and use
### The purpose of this repo is solely for portfolio

## Specification

- **OS:** Ubuntu 26.04 LTS (upgraded from 22.04 due to soon to be EOL)

## How to upgrade the bastion image

1. Run the [bastion pipeline](#).
2. Take the bastion version from the pipeline output (for example `2.16.35`) and set it in the [infra repo](#).
3. Run infra pipeline

## Documentation (Redacted)

- [How to use the bastion](#)
- [Session recording](#)
- [Packer on Azure](#)
