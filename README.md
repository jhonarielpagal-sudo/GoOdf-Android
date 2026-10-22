# GoOdf Mobile

Android editor para sa GrandOrgue organ definition files (`.organ`), inspirado ng
[GoOdf](https://github.com/GrandOrgue/GoOdf). Bagong app ito (Flutter), hindi direktang port.

## Ano ang kaya nito ngayon (MVP)

- Buksan at i-save ang `.organ` file
- Tree view na naka-group ayon sa uri (Organ, Manual, Stop, Rank, Panel, atbp.)
- I-edit ang value ng bawat key, magdagdag o magbura ng key
- Magdagdag, magbura at magpalit ng pangalan ng section
- Awtomatikong update ng `NumberOf...` count sa `[Organ]`
- Search, at share ng file

## Wala pa

Graphical na panel rendering, drag and drop, validation ng mga reference, at ang
mas detalyadong form editors ng GoOdf. Ito ang susunod na gawin.

## Paano kumuha ng APK

1. I-push ang project na ito sa sarili mong GitHub repo (branch `main`).
2. Pumunta sa **Actions** > **Build Android APK**. Awtomatiko itong tatakbo sa bawat push.
3. Pagkatapos, buksan ang run at i-download ang artifact na `goodf-mobile-apk`.
4. Para sa release: mag-push ng tag, hal. `git tag v0.1.0 && git push --tags`. Ilalagay ang APK sa Releases.

Ang APK ay naka-sign gamit ang debug key, kaya sapat ito para sa pansariling gamit at pagsubok.
I-enable ang "Install unknown apps" sa Android para ma-install ito.

## Lokal na build

```
flutter create --platforms=android --project-name goodf_mobile --org org.goodf .
flutter pub get
flutter run
```

## Paalala

Laging gumamit ng kopya ng `.organ` file. Inaalis ng parser ang mga inline `;` comment
sa dulo ng value (tulad din ng GoOdf).

## License

GPL-3.0, dahil gumagamit ito ng GoOdf bilang reference. Ilagay ang `LICENSE` file ng GPL-3.0
sa repo mo.
