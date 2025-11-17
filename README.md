# BuildChain Infrastructure Trust 🏗️

On-chain registry and trust layer for critical infrastructure projects (roads, bridges, energy, digital infra) secured by the Stacks blockchain.

## Contract overview 🔍

The core contract is `buildchain-infrastructure-trust.clar` and provides:

- Registration of infrastructure projects with metadata
- Ownership and transfer of project control
- Community and auditor ratings per project
- Aggregated trust scores updated on-chain
- Block-aware timestamps using `stacks-block-height` and `get-stacks-block-info?`

## Data model 🧱

### Global state

- `owner: principal` – contract owner
- `last-project-id: uint` – running counter for project IDs

### Maps

- `infrastructure-projects`:
  - key: `{ id: uint }`
  - value: `{ name, owner, metadata-url, created-at, last-updated-at, trust-score, total-ratings }`
- `project-ratings`:
  - key: `{ id: uint, rater: principal }`
  - value: `{ score: uint }`

## Public functions 🚀

### `set-owner (new-owner principal)`
Change the contract owner. Callable only by the current owner.

### `register-project (name (string-ascii 64)) (metadata-url (string-utf8 128))`
Registers a new infrastructure project, owned by `tx-sender`, and returns the new `project-id`.

### `update-project-metadata (project-id uint) (name (string-ascii 64)) (metadata-url (string-utf8 128))`
Updates name and metadata URL for an existing project. Only the project owner can call this.

### `transfer-project-ownership (project-id uint) (new-owner principal)`
Transfers ownership of a project to another principal.

### `rate-project (project-id uint) (score uint)`
Adds a rating for a project in the range `0..100`. Each principal can rate a project once. The contract recalculates the aggregated `trust-score` using the existing average and total ratings.

## Read-only functions 📖

- `get-owner()` – returns the contract owner
- `get-last-project-id()` – returns the last issued project ID
- `get-current-block-height()` – returns `stacks-block-height`
- `get-current-block-time()` – returns the current block time using `get-stacks-block-info?`
- `get-project (project-id)` – returns the full project record
- `get-project-trust-score (project-id)` – returns the aggregated trust score
- `get-project-total-ratings (project-id)` – returns the number of ratings for a project
- `has-rated (project-id rater)` – `true` if `rater` has already rated the project
- `get-project-rating-by (project-id rater)` – returns a specific rating for a project
- `is-contract-owner (who)` – `true` if `who` is the contract owner
- `is-project-owner (project-id who)` – `true` if `who` owns the project

## Running checks ✅

From the project root (where `Clarinet.toml` is located):

```bash path=null start=null
clarinet check
```

This runs type checks and analysis passes for the `buildchain-infrastructure-trust` contract.

## Using Clarinet console 🧪

Start the console:

```bash path=null start=null
clarinet console
```

Example interactions:

```clarity path=null start=null
;; inside clarinet console
(contract-call? .buildchain-infrastructure-trust register-project "Bridge Alpha" u"https://example.com/bridge-alpha")

(define-constant bridge-id u1)

(contract-call? .buildchain-infrastructure-trust rate-project bridge-id u90)

(contract-call? .buildchain-infrastructure-trust get-project bridge-id)
(contract-call? .buildchain-infrastructure-trust get-project-trust-score bridge-id)
```

## Deployment 🌐

1. Build and test locally with Clarinet.
2. Deploy the contract using your preferred deployment flow (Stacks node, Hiro wallet, or deployment scripts).
3. Point off-chain services (UIs, data indexers, auditors) to this contract to power infrastructure trust workflows.
