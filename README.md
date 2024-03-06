# Immunefi Protocol

[![GitHub Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry]
[![Styled with Prettier][prettier-badge]][prettier]

[gha]: https://github.com/immunefi-team/vaults/actions
[gha-badge]: https://github.com/immunefi-team/vaults/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[prettier]: https://prettier.io
[prettier-badge]: https://img.shields.io/badge/Code_Style-Prettier-ff69b4.svg


## High level description

A project can prove their proof of assets deploying a vault via Immunefi's Dashboard and depositing assets. A Vault is implemented as a [Gnosis Safe](https://github.com/safe-global/safe-contracts), with the attachment of a Guard - Immunefi Guard - and a module - Immunefi Module, set in the moment of Safe setup.

Assets inside a project's Vault are displayed to the bug reporter, serving as proof of funds for bug report reward. Projects can withdraw their assets or a portion of them by queuing a withdrawal operation. This operation is timelocked and can only be executed after a certain cooldown period.

A project pays a successful report submission by a whitehat using the [RewardSystem](./src/RewardSystem.sol). Proper bounty reward distribution logic will be borrowed from the [VaultDelegate](./src/common/VaultDelegate.sol), which handles automatically the whitehat reward and the Immunefi fee processing.

The [RewardSystem](./src/RewardSystem.sol) component also allows for reward enforcement if the project does not act on the decision made by mediation.

If either project or whitehat is unsatisfied with the mediation outcome, an arbitration request can be done using the [Arbitration](./src/Arbitration.sol) component. An external party will be called on to decide the final outcome. Any reward distribution will be enforced.

## Testing

### Pre Requisites

You will need the following software on your machine:

- [Git](https://git-scm.com/downloads)
- [Foundry](https://github.com/foundry-rs/foundry)
- [Node.Js](https://nodejs.org/en/download/)
- [Yarn](https://yarnpkg.com/)

### Tests

1. Run `forge test`

### Disclosures

If you discover any security issues, please follow the [Immunefi Bounty Program](https://immunefi.com/bounty/immunefi/) to submit.

## Audits

- [Internal Audit by Immunefi Triaging Team to the Splitter version](./audits/2023-02-03%20-%20Immunefi%20-%20Internal%20Audit%20of%20the%20Vaults%20system.pdf)
- [External Audit by Ourovoros to the Splitter version](./audits/2023-02-13%20-%20Ourovoros%20Audit.md)
- [Internal Audit by Immunefi Triaging Team to the Vault System and Arbitration MVP](./audits/2023-06-06%20-%20Immunefi%20-%20Internal%20Audit%20of%20the%20Vault%20System%20and%20Arbitration%20MVP.pdf)
- [External Audit by Ackee Blockchain](./audits/ackee-blockchain-immunefi-vault-final-report.pdf)
- [External Audit by Dedaub](./audits/dedaub-arbitration-immunefi-report.pdf)
