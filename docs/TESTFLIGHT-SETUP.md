# TestFlight setup checkpoint

## What works now
- Native SwiftUI Builds list, creation, local persistence, and detail screen.
- Simulator workflow builds, launches, and tests creation/cancel/validation/relaunch.
- Separate testflight-prepare.yml checks a Release archive for an actual iPhone CPU.
- Preparation uses no Apple credentials and does not sign, export an IPA, or upload.
- An unsigned archive is NOT installable. A passing preparation run is NOT TestFlight validation.
- Main and the saved Expo recovery branch are unchanged.

## App identity
- Display name: Brick by Brick
- Proposed App Store Connect name: Brick by Brick (availability not checked)
- Bundle ID: com.steveypugs.brickbybrick
- Proposed SKU: brick-by-brick-ios
- Platform: iOS, iPhone only
- Version: 0.1.0
- Preparation build number: workflow run number plus attempt number.
  Before the first upload, confirm it exceeds any previously uploaded build number.

## Remaining gates, in order
1. Confirm renewed membership is active in Apple Developer and App Store Connect.
2. Register the explicit Bundle ID and create the app record with that same ID.
3. Select a hosted macOS/Xcode toolchain satisfying Apple's CURRENT upload SDK requirements.
   The preparation runner is not a promise that its default Xcode is upload-eligible.
4. Add a valid app icon asset catalog and check distribution metadata/export compliance.
5. Establish distribution signing: Apple Distribution certificate with its private key
   and an App Store provisioning profile for the correct team and Bundle ID.
   We will arrange the credential setup without requiring Stephen's old Mac.
6. Establish upload authentication with a suitably scoped App Store Connect API key.
7. With Stephen's approval, store credentials directly in GitHub Actions secrets,
   preferably a protected TestFlight environment. Never paste private keys, passwords,
   certificates with private keys, or recovery codes into chat or commit them.
   Do not revoke or replace any existing Apple certificate without explicit approval.
8. Add a manually triggered signed archive/export/upload workflow with preflight
   checks, a separate explicit upload choice, and temporary signing-key cleanup.
   Keep credentials out of pull-request builds; grant only contents: read.
9. Validate and upload one signed build. Wait for Apple processing, resolve any
   compliance questions, then add Stephen as an internal tester and install via TestFlight.

## Running preparation
Push relevant changes on native-ios/cloud-build-proof to run automatically.
GitHub only exposes workflow_dispatch for workflows present on the default branch;
do not merge to main solely to make a Run workflow button appear.
This preparation workflow deliberately contains NO signing or upload steps.
Do not interpret its green check as permission or readiness to release publicly.

## References
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
- https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications
