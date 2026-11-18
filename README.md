**planned to rewire everything for actual usage**

## What?
**This is heavily redacted fork of bastion image IaC I personally maintain**  
The purpose of this repo is solely for portfolio

## Bastion
Bastion host image, built with Packer on Azure, stored in image gallery

## Features running in upstream (might be redacted here)
- Session recording via eventhub & storage account
- JIRA Ticket validation on bastion access
- AD SSH user login, no local SSH account exposed
- etc

## Specification
- **OS:** Ubuntu 26.04 LTS

## How to upgrade the bastion image
1. Run the [bastion pipeline](#).
2. Take the bastion version from the pipeline output (for example `2.16.35`) and set it in the [infra repo](#).
3. Run infra pipeline

## Documentation (Redacted)
- [How to use the bastion](#)
- [Session recording](#)
- [Packer on Azure](#)
