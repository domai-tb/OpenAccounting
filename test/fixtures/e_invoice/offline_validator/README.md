# Offline validator fixtures

These positive controls are official examples, pinned by content hash:

| File | Source | SHA-256 |
| --- | --- | --- |
| `xrechnung_valid_01_01a.xml` | [KoSIT XRechnung testsuite business case](https://projekte.kosit.org/xrechnung/xrechnung-testsuite/-/raw/master/src/test/business-cases/standard/01.01a-INVOICE_ubl.xml) | `74fb09c609d5fba15a8c543060998d3b92858f56a81fb5b0ed244d6794e498d1` |
| `zugferd_valid_en16931_cii.xml` | FNFE-MPE `France_RFE` v1.4.0.04, `FNFE_RFE_INVOICE/Z.example/TEST/CII/EN16931/UC1_F202500003_00-INV_20250701_EN16931_FX_CII_Commentee.xml` | packaged LF-normalized copy `7b31ddb8303f66b0b893433d9210ac88afb0bc607bbbbe06d5add819c4d3d0f5`; upstream bytes `8f134f512fe3a8a3847b5f54c73411653b1da70f18c2e97e176f7a23b5cff085` |

The CII fixture is line-ending and trailing-whitespace normalized for clean diffs; its XML values and structure are unchanged. The validator bundle's selected XML/XSD/XSL/Schematron files are normalized the same way, and `manifest.json` pins the exact packaged bytes separately from the official upstream archive hashes.

Negative controls are produced in the test from these valid files: the XRechnung seller electronic address is removed, and the CII seller name is emptied. This keeps the expected XML changes visible next to their asserted official rule IDs without maintaining synthetic invoice documents as source fixtures.
