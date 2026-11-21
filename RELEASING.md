# Releasing vim-ditto

vim-ditto uses [Semantic Versioning](https://semver.org/):

- `MAJOR` for incompatible public API changes.
- `MINOR` for backwards-compatible features. While the project is below
  `1.0.0`, this also covers breaking changes to the public API.
- `PATCH` for backwards-compatible fixes.

## Sources of truth

- `VERSION` contains the current version.
- The headers in `autoload/ditto.vim` and `plugin/ditto.vim` mirror it.
- `CHANGELOG.md` has a section for every release.
- Releases are annotated Git tags named `vX.Y.Z`.

`make release-check` enforces that `VERSION`, both file headers, and the
changelog agree.

## Release checklist

1. Update `VERSION`, the two file headers, and `CHANGELOG.md`.
2. Run the metadata check:

   ```sh
   make release-check
   ```

3. Run the full verification suite:

   ```sh
   make test
   make e2e
   ```

4. Commit the release changes.
5. Create an annotated tag and push it:

   ```sh
   git tag -a vX.Y.Z -m "vim-ditto vX.Y.Z"
   git push origin master
   git push origin vX.Y.Z
   ```

6. Create the GitHub release from the tag:

   ```sh
   gh release create vX.Y.Z --title "vim-ditto vX.Y.Z" --notes-from-tag
   ```

   Optionally attach the end-to-end contact sheet:

   ```sh
   gh release create vX.Y.Z --title "vim-ditto vX.Y.Z" --notes-from-tag \
     test/e2e/out/contact-sheet.png
   ```

7. For fixes reported in an issue, ask the reporter to retest before closing
   the issue.
