# Workspace Archive v1 (`.pikaarchive`)

This document defines the first strict JSON workspace archive contract for Pika.

## Envelope

A `.pikaarchive` file is UTF-8 JSON with this envelope:

- `format` (string, required): must be `"pika.workspace.archive"`.
- `version` (integer, required): must be `1`.
- `exportedAt` (string, required): ISO8601 UTC timestamp.
- `generator` (object, optional): metadata about the producing tool.
  - `name` (string, required when `generator` exists)
  - `version` (string, required when `generator` exists)
- `workspace` (object, required): normalized workspace payload.

## Workspace Payload

`workspace` uses Pika domain terms and normalized arrays.

- `businessProfile` (object, required)
- `clients` (array, required)
- `projects` (array, required)
- `buckets` (array, required)
- `timeEntries` (array, required)
- `fixedCosts` (array, required)
- `invoices` (array, required)
- `invoiceLineItems` (array, required)

### businessProfile

- `id` (UUID)
- `businessName` (string)
- `personName` (string)
- `email` (string)
- `phone` (string)
- `address` (string)
- `taxIdentifier` (string)
- `economicIdentifier` (string)
- `invoicePrefix` (string)
- `nextInvoiceNumber` (integer)
- `currencyCode` (string)
- `paymentDetails` (string)
- `taxNote` (string)
- `defaultTermsDays` (integer)

### clients

Each client object:

- `id` (UUID)
- `name` (string)
- `email` (string)
- `billingAddress` (string)
- `defaultTermsDays` (integer)
- `isArchived` (boolean)

### projects

Each project object:

- `id` (UUID)
- `clientID` (UUID)
- `name` (string)
- `currencyCode` (string)
- `isArchived` (boolean)

### buckets

Each bucket object:

- `id` (UUID)
- `projectID` (UUID)
- `name` (string)
- `status` (`open`, `ready`, `finalized`, `archived`)
- `defaultHourlyRateMinorUnits` (integer)

### timeEntries

Each time entry object:

- `id` (UUID)
- `bucketID` (UUID)
- `workDate` (ISO8601 UTC timestamp)
- `startMinuteOfDay` (integer, optional)
- `endMinuteOfDay` (integer, optional)
- `durationMinutes` (integer)
- `description` (string)
- `isBillable` (boolean)
- `hourlyRateMinorUnits` (integer)

### fixedCosts

Each fixed-cost object:

- `id` (UUID)
- `bucketID` (UUID)
- `date` (ISO8601 UTC timestamp)
- `description` (string)
- `quantity` (integer)
- `unitPriceMinorUnits` (integer)
- `isBillable` (boolean)

### invoices

Each invoice object:

- `id` (UUID)
- `projectID` (UUID)
- `bucketID` (UUID)
- `number` (string)
- `template` (string)
- `issueDate` (ISO8601 UTC timestamp)
- `dueDate` (ISO8601 UTC timestamp)
- `servicePeriod` (string)
- `status` (`finalized`, `sent`, `paid`, `cancelled`)
- `totalMinorUnits` (integer)
- `currencyCode` (string)
- `note` (string)
- `businessProfileSnapshot` (object)
- `clientSnapshot` (object)
- `projectSnapshot` (object)
- `bucketSnapshot` (object)

Snapshot objects contain exactly the values needed to preserve historical invoice rendering context.

### invoiceLineItems

Each line item object:

- `id` (UUID)
- `invoiceID` (UUID)
- `sortOrder` (integer)
- `description` (string)
- `quantityLabel` (string)
- `amountMinorUnits` (integer)

## Validation Expectations

Decoder behavior for v1 must reject:

- wrong `format`
- unsupported `version`

Archive JSON encoding behavior for v1 must be:

- pretty-printed
- ISO8601 date strings
- integer money values in minor units (for example `10000`, not decimal currency strings)

## Notes

- Archive payload is intentionally normalized for stable tooling and deterministic transforms.
- Activity history is not part of v1.
- UI import/export workflows are out of scope for this contract definition.

## Example

```json
{
  "exportedAt" : "2026-05-02T00:00:00Z",
  "format" : "pika.workspace.archive",
  "generator" : {
    "name" : "pika-tests",
    "version" : "1.0.0"
  },
  "version" : 1,
  "workspace" : {
    "buckets" : [
      {
        "defaultHourlyRateMinorUnits" : 10000,
        "id" : "40000000-0000-0000-0000-000000000001",
        "name" : "Ready Snapshot",
        "projectID" : "30000000-0000-0000-0000-000000000001",
        "status" : "ready"
      }
    ],
    "businessProfile" : {
      "address" : "1 Harbour Way",
      "businessName" : "North Coast Studio",
      "currencyCode" : "EUR",
      "defaultTermsDays" : 14,
      "economicIdentifier" : "ECO123",
      "email" : "billing@northcoast.example",
      "id" : "10000000-0000-0000-0000-000000000001",
      "invoicePrefix" : "NCS",
      "nextInvoiceNumber" : 42,
      "paymentDetails" : "IBAN DE00 1234",
      "personName" : "Avery North",
      "phone" : "+49 555 0100",
      "taxIdentifier" : "DE123",
      "taxNote" : "VAT exempt"
    },
    "clients" : [
      {
        "billingAddress" : "1 Snapshot Way",
        "defaultTermsDays" : 21,
        "email" : "billing@snapshot.example",
        "id" : "20000000-0000-0000-0000-000000000001",
        "isArchived" : false,
        "name" : "Snapshot Client"
      }
    ],
    "fixedCosts" : [
      {
        "bucketID" : "40000000-0000-0000-0000-000000000001",
        "date" : "2026-05-01T00:00:00Z",
        "description" : "Design package",
        "id" : "60000000-0000-0000-0000-000000000001",
        "isBillable" : true,
        "quantity" : 1,
        "unitPriceMinorUnits" : 32000
      }
    ],
    "invoiceLineItems" : [
      {
        "amountMinorUnits" : 10000,
        "description" : "Ready Snapshot",
        "id" : "80000000-0000-0000-0000-000000000001",
        "invoiceID" : "70000000-0000-0000-0000-000000000001",
        "quantityLabel" : "1h",
        "sortOrder" : 0
      }
    ],
    "invoices" : [
      {
        "bucketID" : "40000000-0000-0000-0000-000000000001",
        "bucketSnapshot" : {
          "name" : "Ready Snapshot"
        },
        "businessProfileSnapshot" : {
          "address" : "1 Harbour Way",
          "businessName" : "North Coast Studio",
          "economicIdentifier" : "ECO123",
          "email" : "billing@northcoast.example",
          "paymentDetails" : "IBAN DE00 1234",
          "personName" : "Avery North",
          "phone" : "+49 555 0100",
          "taxIdentifier" : "DE123",
          "taxNote" : "VAT exempt"
        },
        "clientSnapshot" : {
          "billingAddress" : "1 Snapshot Way",
          "email" : "billing@snapshot.example",
          "name" : "Snapshot Client"
        },
        "currencyCode" : "EUR",
        "dueDate" : "2026-05-15T00:00:00Z",
        "id" : "70000000-0000-0000-0000-000000000001",
        "issueDate" : "2026-05-01T00:00:00Z",
        "note" : "Thank you.",
        "number" : "NCS-2026-042",
        "projectID" : "30000000-0000-0000-0000-000000000001",
        "projectSnapshot" : {
          "name" : "Snapshot Project"
        },
        "servicePeriod" : "May 2026",
        "status" : "finalized",
        "template" : "kleinunternehmerClassic",
        "totalMinorUnits" : 42000
      }
    ],
    "projects" : [
      {
        "clientID" : "20000000-0000-0000-0000-000000000001",
        "currencyCode" : "EUR",
        "id" : "30000000-0000-0000-0000-000000000001",
        "isArchived" : false,
        "name" : "Snapshot Project"
      }
    ],
    "timeEntries" : [
      {
        "bucketID" : "40000000-0000-0000-0000-000000000001",
        "description" : "Billable work",
        "durationMinutes" : 60,
        "endMinuteOfDay" : 600,
        "hourlyRateMinorUnits" : 10000,
        "id" : "50000000-0000-0000-0000-000000000001",
        "isBillable" : true,
        "startMinuteOfDay" : 540,
        "workDate" : "2026-05-01T00:00:00Z"
      }
    ]
  }
}
```
