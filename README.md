# GoOdf Mobile

An Android editor for GrandOrgue organ definition files (`.organ`), modelled on the
desktop tool [GoOdf](https://github.com/GrandOrgue/GoOdf). It is a new app (Flutter),
not a direct port, and it follows GoOdf's layout and workflow.

## What it does

- Open and write `.organ` files (UTF-8 or Latin-1, written back as UTF-8)
- Organ tree like GoOdf: Manuals (with Stops, Couplers, Divisionals), Windchestgroups,
  Enclosures, Tremulants, Ranks, Switches, Reversible Pistons, Divisional Couplers,
  Generals, Panels. Always visible on tablets, a drawer on phones.
- A proper form for each element (Organ, Manual, Stop, Coupler, Tremulant, Switch,
  Windchestgroup, Enclosure, Rank) with Yes/No toggles, drop-downs and number fields
- Available / Referenced lists with Add and Remove for ranks, switches, tremulants
  and enclosures
- Rank editor with a pipe tree (sample, attacks, releases, tuning...)
- Add and remove elements. Numbering, references and the NumberOf... counts in
  `[Organ]` are kept consistent, including after deleting something in the middle.
- **Tools > Import Stops/Ranks**: copy stops and ranks from another `.organ` file.
  The copies are real: ranks keep all their pipes and sample paths, stops are linked
  to the copied ranks, and numbering is fixed up.
- **Tools > Check file**: reports broken references and wrong counts
- Every key in the file stays editable under "All other keys", and keys the app
  does not know are never dropped.

New drawstops and buttons are marked as displayed, so GrandOrgue lays them out on its
built-in default panel. There is no graphical panel editor yet; panels can be edited
as raw keys.

## Getting the APK

1. Push this project to your own GitHub repo (branch `main`).
2. **Actions > Build Android APK** runs on every push.
3. Download the artifact `goodf-mobile-apk` from the finished run.
4. For a release, push a tag such as `v0.2.0` and the APK is attached to the release.

The APK is signed with the debug key, which is fine for personal use. Allow
"Install unknown apps" on the phone to install it.

## Local build

```
flutter create --platforms=android --project-name goodf_mobile --org org.goodf .
flutter pub get
flutter run
```

## Notes

- Always work on a copy of your `.organ` file.
- Sample paths in an organ file are relative to the file's folder. When importing from
  another organ, use the "Sample path prefix" field (for example `..\OtherOrgan\`) so
  GrandOrgue can still find the samples.

## License

GPL-3.0, because GoOdf (GPL-3.0) was used as the reference. Add a `LICENSE` file with
the GPL-3.0 text to your repo.
