# macOS hosted image spike — 2026-08-23

**Classification: PASS for the macOS hosted-engine spike; iOS promotion remains unmet.** A copy-only Mach-O transformation to `MH_DYLIB` loads successfully through `dlopen` on macOS, and the harness invokes the original `LC_MAIN` entry.

- Input: thin ARM64 copy of the official v469e main executable.
- Transformations on the copy: `MH_EXECUTE → MH_DYLIB`, `__PAGEZERO` size zeroed, six dependency strings changed to `@loader_path/Frameworks/...`, Foundation weak-load command repurposed as `LC_ID_DYLIB`, bind ordinals adjusted, and ad-hoc code signing.
- Loader result: both `RTLD_NOW` and `RTLD_LAZY` report `hosted Mach-O load succeeded`.
- Entry result: original engine logs `Unreal engine initialized`, `SDLClient initialized`, `Frucore: Using RGB10A2 frame buffer`, `Game engine initialized`, and `Entering main loop`.
- Screenshot: `entry-screen.png`.
- Evidence: `build/macos-hosted/evidence/` and this dated folder.

This is macOS hosted-engine evidence only. It does not prove iOS compatibility, code signing on iOS, or physical-device execution, and does not promote G3.
