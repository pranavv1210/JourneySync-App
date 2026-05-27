```markdown
# JourneySync-App Development Patterns

> Auto-generated skill from repository analysis

## Overview
This skill provides a comprehensive guide to the development patterns and conventions used in the JourneySync-App repository. The codebase is written in Kotlin and follows consistent conventions for file naming, imports, exports, and commit messages. While no specific framework is detected, the repository demonstrates clear organization and maintainability practices suitable for Kotlin applications.

## Coding Conventions

### File Naming
- **Style:** snake_case
- **Example:**  
  ```plaintext
  user_profile_manager.kt
  journey_sync_service.kt
  ```

### Import Style
- **Style:** Relative imports are used to reference other files or modules within the project.
- **Example:**  
  ```kotlin
  import com.journeysync.data.user_profile
  import com.journeysync.utils.date_utils
  ```

### Export Style
- **Style:** Named exports are used to expose specific classes, functions, or objects.
- **Example:**  
  ```kotlin
  // In user_profile_manager.kt
  class UserProfileManager { ... }
  
  // Usage in another file
  import com.journeysync.data.UserProfileManager
  ```

### Commit Messages
- **Pattern:** Conventional commits with the `feat` prefix.
- **Example:**  
  ```
  feat: add user authentication to journey sync flow
  ```

## Workflows

### Feature Development
**Trigger:** When adding a new feature to the application  
**Command:** `/feature-development`

1. Create a new branch for your feature.
2. Implement the feature following the coding conventions.
3. Write or update tests in files matching `*.test.*`.
4. Commit changes using the `feat:` prefix and a concise description.
5. Open a pull request for review.

### Code Import/Export
**Trigger:** When sharing or reusing code across modules  
**Command:** `/import-export`

1. Use relative imports to reference other modules.
2. Export classes or functions using named exports.
3. Ensure file names use snake_case for consistency.

## Testing Patterns

- **Framework:** Not explicitly detected; use standard Kotlin testing practices.
- **File Pattern:** Test files follow the `*.test.*` naming convention.
- **Example:**  
  ```plaintext
  journey_sync_service.test.kt
  ```
- **Typical Test Structure:**  
  ```kotlin
  import org.junit.Test
  import kotlin.test.assertEquals

  class JourneySyncServiceTest {
      @Test
      fun testSync() {
          // Arrange
          val service = JourneySyncService()
          // Act
          val result = service.sync()
          // Assert
          assertEquals(expected, result)
      }
  }
  ```

## Commands
| Command                | Purpose                                         |
|------------------------|-------------------------------------------------|
| /feature-development   | Start a new feature development workflow        |
| /import-export         | Reference for importing and exporting code      |
```
