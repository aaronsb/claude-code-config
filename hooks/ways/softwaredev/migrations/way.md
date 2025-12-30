---
keywords: migrat|schema|database.?change|alter.?table
---
# Migrations Way

## Before Migrating
- Backup the data
- Test migration on copy of production data
- Plan rollback strategy

## Writing Migrations
- One logical change per migration
- Make migrations reversible when possible
- Don't modify old migrations - create new ones
- Be careful with data migrations vs schema migrations

## Deployment
- Run migrations before deploying new code
- Or: make schema changes backward compatible
- Large tables? Consider online schema change tools
