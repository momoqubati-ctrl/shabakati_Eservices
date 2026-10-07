# shabakti_eservices

## Production access and payment validation

Admin API routes and the admin dashboard require the Supabase Auth user's
server-managed `app_metadata.role` claim to equal `admin`. Assign this claim
only through a trusted administrative process; never use the user-editable
`user_metadata` for authorization. Requests that start a BasGate payment must
include the cart's product IDs and quantities. The API recalculates prices
from server-side catalog settings and rejects a requested amount that differs
from the canonical total.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
