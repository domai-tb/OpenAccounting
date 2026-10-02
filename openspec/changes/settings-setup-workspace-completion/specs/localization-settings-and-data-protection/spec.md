## MODIFIED Requirements

### Requirement: Settings controls change live persisted application state

The Settings workspace MUST expose and persist supported theme, locale, region/formatting, sidebar, company/tax, storage/privacy, and backup preferences through their owning providers or use-case/repository boundaries. A preference change MUST update the running shell without restart where its owning contract requires live behavior. Settings SHALL link to company/tax workspaces instead of duplicating their forms. Every rendered control MUST correspond to a supported persisted preference and MUST expose a localized success or failure state where persistence can fail.

#### Scenario: Language switch retains context

- **GIVEN** the user is on a filtered page and English is supported
- **WHEN** the user changes language in Settings
- **THEN** visible navigation, header, and state copy SHALL change immediately, the current route and filter SHALL remain, and the preference SHALL survive restart

#### Scenario: Theme/privacy changes are durable

- **GIVEN** the user changes theme, a supported region/format preference, or privacy mode
- **WHEN** each setting is applied and the app reloads
- **THEN** the shell and formatted/masked money surfaces SHALL reflect the persisted choice consistently

#### Scenario: Supported region format is durable

- **GIVEN** the user selects a supported date/number formatting region in Settings
- **WHEN** the preference is saved and the app reloads
- **THEN** dates and numbers SHALL use the selected format while accounting currency remains EUR

#### Scenario: Preference persistence fails

- **GIVEN** the underlying settings store rejects an update
- **WHEN** the user changes a preference
- **THEN** Settings SHALL not display the rejected value as saved and SHALL show a localized error while retaining the current route

### Requirement: Local-first backup and integrations report real outcomes

Settings MUST expose the supported local-first backup/restore operations and configured integration controls defined by their owning capabilities. Backup destinations MUST obey the profile-local and external-target boundaries in `backup`; integration tests MUST label the operation actually performed and MUST report failure when that operation fails. SMTP connection feedback MUST NOT imply credentials were authenticated or a message was delivered unless those steps occurred. Settings MAY expose only export actions with a defined OpenSpec scope. Permanent data erasure MUST remain unavailable until an explicit retention/erasure policy is approved; profile removal MUST honor the non-destructive `profiles` contract.

#### Scenario: A backup can be created and restored

- **GIVEN** the user selects a valid supported backup destination
- **WHEN** backup or restore runs
- **THEN** the artifact SHALL be validated, the result and actual target SHALL appear in Settings, and a failed restore SHALL NOT replace the active database

#### Scenario: Integration failure is truthful

- **GIVEN** the user tests an SMTP or other configured integration and its required operation is unavailable
- **WHEN** the test completes or fails
- **THEN** Settings SHALL show a localized truthful result for the tested connection/authentication/delivery stage, keep local operation available, and SHALL NOT show a false success

#### Scenario: Erasure has no approved policy

- **GIVEN** no approved retention/erasure contract exists
- **WHEN** the user opens privacy or profile controls
- **THEN** no permanent accounting-data deletion action SHALL be exposed and non-destructive profile removal SHALL retain the underlying files
