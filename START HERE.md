# On Windows

Your iPhone app was successfully built on GitHub with Xcode 16.4.

Read **WINDOWS-BUILD.md** for cloud rebuilding and installation with Sideloadly.
The build is unsigned, targets physical iPhones/iPads, and requires iOS 17+.
It has not yet been tested on an actual phone.

Build: https://github.com/kuba154825/untitled-compressor-ios/actions/runs/42525718155

# On a Mac

Open **UntitledCompressor.xcodeproj** → wait for package downloads → choose an **iPhone simulator** → press **Run**.

To run on your iPhone, choose your **Signing Team**, set a unique **Bundle Identifier**, select the connected iPhone, and Run.

Use **Product → Test** before making a release. Detailed steps and the current verification limits are in **README.md**.

This ZIP contains editable source. The IPA is a separate download from the
successful GitHub Actions build. This repository is public with the owner's approval.
