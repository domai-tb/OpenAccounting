# Offline XML validator bundle

This directory contains the validator engine, local rule assets, pinned checksums, and required notices. Runtime validation has no download path. The app must have Java 11 or newer available as `java` (or receive an explicit executable path); when Java or any verified asset is missing, the API returns `unavailable` and never treats the invoice as valid.

The selected profiles match the current XML emitters: XRechnung 3.0 UBL Invoice 2.1 with EN 16931 and XRechnung CIUS rules, and ZUGFeRD 2.5.2 CII D22B with the EN16931 profile. BASIC, EXTENDED, CreditNote, CII XRechnung, and other document types are outside this package and must remain unsupported until their exact emitter profile and official rules are pinned. PDF/A validation is a release-verification step, not part of this XML package.

## Pinned sources

| Component | Pin | Source and integrity |
| --- | --- | --- |
| KoSIT Validator CLI | 1.6.3 standalone JAR; Java 11+ | [Maven Central artifact](https://repo1.maven.org/maven2/org/kosit/validator/1.6.3/validator-1.6.3-standalone.jar); SHA-256 `799e64befca97d4080e03608c80b85dd5a5ecc5f4ae4f35d1116ec2855b9a7c9` |
| XRechnung validator configuration | tag `v2026-08-31`, commit `b436fc4bf05ad501ab5cbb4a53fdffee3d4e18be`; XRechnung 3.0.2, Schematron 2.6.0 | [Official release archive](https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/download/v2026-08-31/xrechnung-3.0.2-validator-configuration-2026-08-31.zip); SHA-256 `2530cd107c414511c5d0462ec10f886910395abfca820db82e83d70bf01221a8` |
| EN16931 UBL Schematron | CEN validation artefacts 1.3.16 | [Official release](https://github.com/ConnectingEurope/eInvoicing-EN16931/releases/tag/validation-1.3.16); local compiled XSL is from the pinned KoSIT archive |
| UBL schemas | OASIS UBL 2.1 | [Official OASIS release](https://docs.oasis-open.org/ubl/os-UBL-2.1/UBL-2.1.zip); original copyright and reuse notices remain in every schema file |
| ZUGFeRD / Factur-X EN16931 rules | FNFE-MPE `v1.4.0.04`, commit `97ba0f3d4ef2abed5780e9490d5c3a2be832ab1d`; Factur-X 1.09.2, CII D22B | [Official release](https://github.com/fnfempe/France_RFE/releases/tag/v1.4.0.04); source archive SHA-256 `0314dec4b3bb2d677f253165ee72812d093604f7f346c9cf64f3357b32a56c45` |

`manifest.json` lists each runtime and license file with SHA-256. The Dart adapter pins the manifest digest and verifies every runtime file before extracting it. The selected KoSIT configuration and FNFE-MPE technical artifacts are Apache-2.0; CEN EN16931 validation artefacts are EUPL-1.2. The standalone JAR's `LICENSE.validator` and `META-INF/NOTICE` full text, including third-party component notices, is retained in `licenses/`; only trailing whitespace and the terminal blank line are normalized for clean diffs.

Selected XML, XSD, XSLT, Schematron, and fixture files were normalized to LF line endings and had trailing horizontal whitespace removed for clean diffs. The manifest hashes identify the exact packaged bytes; upstream release/archive hashes above identify the source distributions.

## Run the real validator locally

From the repository root, with the pinned Flutter SDK available through FVM and Java 11+:

```sh
java -jar assets/e_invoice_validator/validator-1.6.3-standalone.jar \
  -s assets/e_invoice_validator/scenarios.xml \
  -r assets/e_invoice_validator \
  -o /tmp/einvoice-validation-reports \
  test/fixtures/e_invoice/offline_validator/xrechnung_valid_01_01a.xml \
  test/fixtures/e_invoice/offline_validator/zugferd_valid_en16931_cii.xml
```

The package is wired into `EInvoiceService` for offline XML validation. Production ZUGFeRD finalization validates CII before side effects, embeds the validated payload in the generated PDF, and writes the same bytes to a `.zugferd.xml` sidecar. The generator adds Factur-X attachment structure and PDF/A-3b metadata, but no app-generated hybrid has passed veraPDF; this package makes no PDF/A conformance claim. Linux real-engine tests run with the system Java executable. Windows and macOS Java discovery, private-runtime packaging, and process behavior still need platform evidence.
