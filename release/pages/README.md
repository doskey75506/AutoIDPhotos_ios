# GitHub Pages · ID Photo Maker / 证件照拼版

Prepared: 2026-11-24. Target: current AutoIDPhoto workspace, iOS app version 1.0, bundle `com.jialishen.AutoIDPhoto`.

## Delivery and current status

- `docs/index.html`: UK English support page, four-step guide, current feature FAQs and a contact section.
- `docs/index.zh-Hans.html`, `docs/privacy.zh-Hans.html`: separate Simplified Chinese pages, selected explicitly through the language link.
- `docs/privacy.html`: UK English privacy policy based on the current implementation.
- `docs/style.css`, `docs/app-icon.png`, `docs/.nojekyll`: local-only assets and static Pages configuration. The icon is copied from the app's current approved icon asset.
- `release/pages/validation.json`: actual validation results and pending information.

**Page content is complete; deployment correction in progress.** The user confirmed developer **Mobile Soft** and support email **shenok.smth@gmail.com** on 2026-11-24. The initial app/source upload is already on `main` in the repository below. Updated pages remove their draft banner and include contact links and support-email handling. A live check found that GitHub Pages was serving the repository README at the root (HTTP 200), while root privacy.html returned 404. This proves the root publishing source was being used. The user then confirmed changing the Pages publishing folder to /docs. That setting change resolves the source mismatch; final public content and language are rechecked after the language update is pushed.

Source upload uses an independent checkout under `/private/tmp` because the workspace does not permit creation of its local `.git` directory. The original workspace remains without Git metadata.

Repository: https://github.com/doskey75506/AutoIDPhotos_ios

Expected project-site URLs if Pages is enabled from this repository without a custom domain (not verified live):

- Support: `https://doskey75506.github.io/AutoIDPhotos_ios/`
- Privacy: `https://doskey75506.github.io/AutoIDPhotos_ios/privacy.html`
- Pages configuration: https://github.com/doskey75506/AutoIDPhotos_ios/settings/pages

## Publishing source and language

- The user confirmed changing GitHub Pages to the `main` branch's `/docs` source. Keep that source; no redundant root HTML entry points are needed.
- Default `index.html` and `privacy.html` pages use English (UK), explicitly `lang="en-GB"`. Chinese is available through separate `index.zh-Hans.html` and `privacy.zh-Hans.html` links. There is no automatic browser-language redirect or remembered Chinese default.
- Both languages share the same local stylesheet and icon. `docs/.nojekyll` keeps these static pages independent from README rendering.
- The public Support and Privacy URLs stay at the site root; `/docs` is the publishing folder, not part of either public URL.

## Confirmed defaults and remaining deployment work

- Developer: **Mobile Soft**.
- Public support/privacy email: **shenok.smth@gmail.com**.
- These values are user-confirmed defaults for subsequent page tasks. Do not ask again unless the user supplies a project-specific replacement.
- `agent-config/page/page.toml` and `agent-config/page/page` contain updated, reviewable agent instruction copies. Writing the shared iOS agent configuration was denied by this session's filesystem restrictions; it is not yet installed there. Run `python3 agent-config/page/install-defaults.py` in a normal terminal to merge the defaults into the existing shared configuration and entry file.
- The page policy distinguishes on-device image processing from messages deliberately sent through Gmail; it does not invent a fixed mailbox deletion schedule. It provides the confirmed email for deletion requests.
- Pages must still be enabled or its current configuration inspected, then the two actual public URLs checked before filling Connect. Page source and app code in Git are not proof of deployment.

## Privacy facts checked

| Topic | Evidence and wording |
| --- | --- |
| Local image processing | `PhotoProcessor.swift`, `MODNetMatting.swift`, `BackgroundCompositor.swift`: Vision/Core ML inference and compositing on device. No image-processing upload API was found. |
| Head geometry | `HeadPlacement`, detection, foreground mask: local crop/foreground processing, not personal identity matching; no model-training path. |
| Camera | `CameraController.swift`: preview/capture only; session stops on exit/background flows. |
| Photo library | `ContentView.swift`, `PhotoModel.swift`: system picker; `.readWrite` authorization for saving/access check; limited and full status paths; no bulk library fetching. |
| In-memory editing | `PhotoModel.swift`: image, generated output and placement in observable memory; no edit-project persistence. |
| Persisted settings | `PhotoModel.swift`, `AppLanguage.swift`: `UserDefaults` photo settings and language. |
| Export retention | `prepareShare` writes UUID-named temporary JPEG/PDF files; no immediate per-share cleanup. Policy explicitly discloses this. |
| Saved and shared copies | Photos creation requests and activity controller; user-selected recipient/storage, iCloud Photos and other system settings can transfer copies. No blanket claim that data never leaves the device. |
| External SDKs/accounts | Current Xcode project has no external package integration; current Swift source has no account/login, advertising SDK or developer analytics path. These facts must be reviewed if dependencies/features change. |
| Backups/deletion | No custom backup exclusion or delete-all control observed. Policy distinguishes deleting app/data, offloading, external copies and backups. It makes no claim that uninstalling removes cloud copies. |
| Website | Static relative assets, no scripts, forms, advertising, analytics or external fonts. GitHub hosting may process technical request information separately. |

## Validation performed

The HTML is checked for balanced elements, a single main page heading, the selected page language, unique anchors, existing relative links and assets, and absence of scripts/external resource loads. Both English and separate Chinese pages are checked. Existing app/source tests were not rerun because no app code was changed.

A browser/phone-width visual check was not completed: this environment has neither `npx` nor `playwright-cli`. No screenshot or browser verification is claimed. Visual review is still required before publication.

## Publishing

1. Inspect the actual GitHub repository and keep its existing branch/protected-branch workflow, Pages configuration and custom domain.
2. Commit and push the confirmed `docs/` pages through that workflow. Source availability alone does not make the Support or Privacy Policy URL publicly reachable.
3. For a repository without an existing Pages setup, go to its **Settings → Pages → Build and deployment → Source: Deploy from a branch**, select the **actual pushed branch** and **/docs**, then Save. Retain an existing Actions-based deployment instead of replacing it.
4. Read the deployed URL from Pages. A project site normally uses `https://<owner>.github.io/<repo>/`, while a user/organization root site or custom domain differs. These are templates, not this project's verified URLs.
5. The Support URL is the actual deployed site root; the Privacy Policy URL is that root plus `privacy.html`. Do not include `docs/` in the deployed URL.
6. Request both public URLs, confirm successful responses and actual page content, then fill Connect. A push alone does not prove deployment.

## Official references checked on 2026-11-24

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): accessible support/contact information and privacy-policy disclosures including retention/deletion.
- [Apple App Review](https://developer.apple.com/app-store/review/): support and privacy policy links for apps.
- [GitHub: Configure a Pages publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site): branch and `/docs` source configuration.
- [GitHub General Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement): hosting-service request/technical information, separate from app-local processing.

- [Google Privacy Policy](https://policies.google.com/privacy): privacy information for the Gmail channel used for voluntary support messages.
