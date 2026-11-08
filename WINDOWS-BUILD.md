# Build for your iPhone from Windows

This project targets iPhone and iPad with iOS 17 or later. The GitHub workflow
builds a Release arm64 app using Xcode on a standard macOS runner. No Mac,
Apple signing certificate, or Apple password is needed for the build.

## Build

Open the repository's **Actions** tab, choose **Build unsigned iPhone IPA**,
then **Run workflow**. It is manual-only so pushes do not consume build time.
Download **Untitled-Compressor-unsigned-IPA** when the run succeeds and unzip it.

Standard GitHub macOS runners are free for public repositories. Private
repositories consume the account's included allowance and may incur charges
when it is exhausted if paid usage is enabled. Confirm your allowance first.
Do not make this private source public without its owner's explicit approval.

## Install

Download Sideloadly from https://sideloadly.io/ on your Windows PC. Follow its
current Windows prerequisite instructions, connect your iPhone over USB, select
the IPA, and sign in with your own Apple account in Sideloadly. Complete device
trust and Developer Mode prompts on your iPhone if requested. A free account
requires app signing to be refreshed every seven days. Do not send your Apple
password to an assistant or put it in this repository.

The IPA is unsigned until Sideloadly signs it; tapping it on the iPhone alone
will not install it. App Store distribution is a separate process.

## What is checked

The workflow checks project structure, performs a real Xcode Release build for
a physical iPhone, verifies arm64 and bundled dynamic framework dependencies,
and checks the IPA ZIP integrity. BUILD-INFO.json records the build details.
A successful build does not prove that compression works on your specific
phone. Import a short SDR MP4 and test compression and sharing after installation.

Generated IPA and diagnostic artifacts expire after three days on GitHub.
Your local download remains available.
