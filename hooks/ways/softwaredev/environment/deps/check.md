---
description: dependency change, package upgrade, version bump, adding library, removing package
vocabulary: dependency package library version upgrade downgrade install add remove npm pip cargo requirements lock
threshold: 2.0
scope: agent
---

## anchor

You are changing project dependencies. Version mismatches and breaking changes are common — verify compatibility.

## check

Before changing dependencies:
- Have you checked the **current version constraints** in the lock file / manifest?
- If upgrading: are there **breaking changes** between the current and target version?
- If adding a new dependency: does this project already have a library that does the same thing?
- Will this change affect other packages that depend on the same library (peer/transitive deps)?
- Is the package **actively maintained** and appropriate for this project's license?
