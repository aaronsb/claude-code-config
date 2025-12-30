---
keywords: endpoint|api.?design|rest|graphql|route
---
# API Design Way

## REST Conventions
- Nouns for resources: `/users`, `/orders`
- HTTP verbs for actions: GET, POST, PUT, DELETE
- Plural resource names
- Nest for relationships: `/users/123/orders`

## Responses
- Consistent envelope or flat structure
- Meaningful HTTP status codes
- Include error details in body
- Paginate collections

## Versioning
- Version in URL (`/v1/`) or header
- Don't break existing clients
- Deprecate before removing

## General
- Idempotent operations where possible
- Rate limiting for protection
- Document as you build
