# Workspace Archive v1 (`.billbiarchive`)

This document defines Billbi's strict v1 workspace archive contract for external tools and agents.

## Envelope

A v1 archive is UTF-8 JSON in a `.billbiarchive` file with this envelope:

- `format` (string, required): must be `billbi.workspace-archive`
- `version` (integer, required): must be `1`
- `exportedAt` (string, required): ISO 8601 timestamp (`YYYY-MM-DDTHH:MM:SSZ`)
- `generator` (object, optional): metadata about the tool that produced the archive
- `workspace` (object, required): normalized workspace payload

`generator` fields:

- `app` (string, required)
- `version` (string, required)
- `build` (string, required)

## Workspace Payload (Normalized)

The `workspace` object uses Billbi domain terms and normalized record tables:

- `onboardingCompleted` (boolean, optional on import, defaults to `false`)
- `businessProfile` (object, required)
- `clients` (array, required)
- `projects` (array, required)
- `buckets` (array, required)
- `timeEntries` (array, required)
- `fixedCosts` (array, required)
- `invoices` (array, required)
- `invoiceLineItems` (array, required)

### Business Profile

Required fields:

- `businessName`, `personName`, `email`, `phone`, `address`
- `taxIdentifier`, `economicIdentifier`
- `invoicePrefix`, `nextInvoiceNumber`
- `currencyCode`, `paymentDetails`, `taxNote`, `defaultTermsDays`

### Clients

Each client requires:

- `id` (UUID)
- `name`, `email`, `billingAddress`
- `defaultTermsDays` (integer)
- `isArchived` (boolean)

### Projects

Each project requires:

- `id` (UUID)
- `clientID` (UUID)
- `name`
- `currencyCode`
- `isArchived` (boolean)

### Buckets

Each bucket requires:

- `id` (UUID)
- `projectID` (UUID)
- `name`
- `status` (`open`, `ready`, `finalized`, `archived`)
- `defaultHourlyRateMinorUnits` (integer)

### Time Entries

Each time entry requires:

- `id` (UUID)
- `bucketID` (UUID)
- `date` (date-only ISO: `YYYY-MM-DD`)
- `startMinuteOfDay` (integer, optional)
- `endMinuteOfDay` (integer, optional)
- `durationMinutes` (integer)
- `description`
- `isBillable` (boolean)
- `hourlyRateMinorUnits` (integer)

### Fixed Costs

Each fixed cost entry requires:

- `id` (UUID)
- `bucketID` (UUID)
- `date` (date-only ISO: `YYYY-MM-DD`)
- `description`
- `amountMinorUnits` (integer)

### Invoices

Each invoice requires:

- `id` (UUID)
- `projectID` (UUID)
- `bucketID` (UUID)
- `number`
- `businessSnapshot` object
- `clientSnapshot` object
- `template` (string)
- `issueDate` (date-only ISO)
- `dueDate` (date-only ISO)
- `servicePeriod`
- `status` (`finalized`, `sent`, `paid`, `cancelled`)
- `totalMinorUnits` (integer)
- `currencyCode`
- `note` (string, optional)

`businessSnapshot` fields:

- `businessName`, `personName`, `email`, `phone`, `address`
- `taxIdentifier`, `economicIdentifier`, `paymentDetails`, `taxNote`

`clientSnapshot` fields:

- `name`, `email`, `billingAddress`

### Invoice Line Items

Each line item requires:

- `id` (UUID)
- `invoiceID` (UUID)
- `sortOrder` (integer)
- `description`
- `quantityLabel`
- `amountMinorUnits` (integer)

## Validation Expectations

v1 archives are strict. Decoding rejects archives when:

- `format` is not `billbi.workspace-archive`
- `version` is not `1`
- `exportedAt` is not a valid ISO 8601 timestamp
- any top-level, workspace-level, or record-level field is not defined by this v1 schema
- date-only fields (`timeEntries.date`, `fixedCosts.date`, `invoices.issueDate`, `invoices.dueDate`) are not valid `YYYY-MM-DD`

Validation rejects archives when:

- any UUID is duplicated within its table
- any relationship points to a missing record:
  `projects.clientID`, `buckets.projectID`, `timeEntries.bucketID`, `fixedCosts.bucketID`, `invoices.projectID`,
  `invoices.bucketID`, or `invoiceLineItems.invoiceID`
- an invoice references a bucket that belongs to a different project than `invoices.projectID`
- `businessProfile.currencyCode`, `projects.currencyCode`, or `invoices.currencyCode` is not a non-empty three-letter uppercase code
- `businessProfile.defaultTermsDays` or `clients.defaultTermsDays` is not positive
- `businessProfile.nextInvoiceNumber` is not positive
- `buckets.defaultHourlyRateMinorUnits`, `timeEntries.hourlyRateMinorUnits`, `fixedCosts.amountMinorUnits`,
  `invoices.totalMinorUnits`, or `invoiceLineItems.amountMinorUnits` is negative
- `timeEntries.durationMinutes` is not positive
- a billable time amount, bucket derived total, or invoice line item sum overflows integer minor units
- `invoices.template` is not one of Billbi's known invoice template raw values
- `invoices.number` is empty after trimming whitespace, or duplicates another invoice number after trimming and case folding
- `invoices.totalMinorUnits` does not equal the sum of its invoice line item `amountMinorUnits`

Money values are integer minor units across the schema. Bucket totals are derived from row-level time entries and fixed costs; they are not stored as canonical archive fields. Activity history is excluded from v1 archives.

## Example Archive

```json
{
  "exportedAt" : "2026-05-02T10:00:00Z",
  "format" : "billbi.workspace-archive",
  "generator" : {
    "app" : "Billbi",
    "build" : "27",
    "version" : "0.1.0"
  },
  "version" : 1,
  "workspace" : {
    "onboardingCompleted" : true,
    "buckets" : [
      {
        "defaultHourlyRateMinorUnits" : 10000,
        "id" : "30000000-0000-0000-0000-000000000001",
        "name" : "Ready Snapshot",
        "projectID" : "20000000-0000-0000-0000-000000000001",
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
        "id" : "10000000-0000-0000-0000-000000000001",
        "isArchived" : false,
        "name" : "Snapshot Client"
      }
    ],
    "fixedCosts" : [
      {
        "amountMinorUnits" : 32000,
        "bucketID" : "30000000-0000-0000-0000-000000000001",
        "date" : "2026-05-01",
        "description" : "Design package",
        "id" : "32000000-0000-0000-0000-000000000001"
      }
    ],
    "invoiceLineItems" : [
      {
        "amountMinorUnits" : 20000,
        "description" : "Ready Snapshot",
        "id" : "41000000-0000-0000-0000-000000000001",
        "invoiceID" : "40000000-0000-0000-0000-000000000001",
        "quantityLabel" : "2h",
        "sortOrder" : 0
      },
      {
        "amountMinorUnits" : 32000,
        "description" : "Design package",
        "id" : "41000000-0000-0000-0000-000000000002",
        "invoiceID" : "40000000-0000-0000-0000-000000000001",
        "quantityLabel" : "1 item",
        "sortOrder" : 1
      }
    ],
    "invoices" : [
      {
        "bucketID" : "30000000-0000-0000-0000-000000000001",
        "businessSnapshot" : {
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
        "dueDate" : "2026-05-15",
        "id" : "40000000-0000-0000-0000-000000000001",
        "issueDate" : "2026-05-01",
        "note" : "Thank you.",
        "number" : "NCS-2026-042",
        "projectID" : "20000000-0000-0000-0000-000000000001",
        "servicePeriod" : "May 2026",
        "status" : "finalized",
        "template" : "kleinunternehmer-classic",
        "totalMinorUnits" : 52000
      }
    ],
    "projects" : [
      {
        "clientID" : "10000000-0000-0000-0000-000000000001",
        "currencyCode" : "EUR",
        "id" : "20000000-0000-0000-0000-000000000001",
        "isArchived" : false,
        "name" : "Snapshot Project"
      }
    ],
    "timeEntries" : [
      {
        "bucketID" : "30000000-0000-0000-0000-000000000001",
        "date" : "2026-05-01",
        "description" : "Billable work",
        "durationMinutes" : 120,
        "endMinuteOfDay" : 660,
        "hourlyRateMinorUnits" : 10000,
        "id" : "31000000-0000-0000-0000-000000000001",
        "isBillable" : true,
        "startMinuteOfDay" : 540
      }
    ]
  }
}
```
