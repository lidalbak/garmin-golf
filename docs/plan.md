# Golf App for Garmin Venu 2

Målet er samme golfskjerm og arbeidsflyter som Approach S72, tilpasset Venu 2. Full funksjonslikhet er ikke oppnådd. Denne planen skiller bygget kode fra verifisert oppførsel og uavklarte avhengigheter.

## Gjennomføring og status

1. **Finn referansen. Delvis utført.** Offisiell S72-manual lastet ned, SHA-256 registrert og skjermillustrasjoner undersøkt. Offentlige nedlastingssider og lokale Garmin-mapper er undersøkt. Ingen autentisk S72-fastvare/appfil funnet. REA-analyse av originalen er blokkert inntil slike bytes finnes; manualen er ikke en programvareanalyse.
2. **Avklar Venu 2-kontrakten. Utført for bygg.** Det eksisterende Garmin SDK 9.1.0 og den installerte `venu2`-profilen brukes. Skjermen er 416 × 416, oppgitt watch-app-minne er 786432 bytes, enhetsprofilen annonserer API 5.0. Ingen SDK eller systemprogramvare installert/oppgradert.
3. **Hent norske baner. Utført med begrensninger.** Bogstad og Bærum: 36 hull, kartlagte spillelinjer, greenpolygoner, par og nærliggende hindergeometri. OSM-endepunkt er ikke dagens flagg. Bogstads motstridende indekser holdes ukjente. Losby utsettes fordi 2026-rutingen er midlertidig og innhentet geometri ufullstendig.
4. **Bygg skjermflyten. Implementert, kompilert.** Hovedskjerm med gul mål-avstand, hvit for-/bakkant og kart til høyre, men egne fonter/vektorer. Ekte OSM-fairwayer, greener, bunkere, vann og skogflater bruker en fargepalett tilpasset S72-referansen. Individuelle kartlagte trær tegnes sammen med illustrerende trekroner i skogområder. Draing, zoom 1–8× og flytting av flagg er lagt inn. Skjermen er rekonstruert fra manualen, ikke validert som identisk med S72. `ui-preview.png` er en separat designforhåndsvisning fra samme geometri og palett, ikke et runtime-bilde.
5. **Bygg lokal golfkjerne. Implementert, kompilert.** GPS-avstander, kartmål, flagg, score, putter, straff, fairway, spillehandicap, Stableford der indeks er kjent, slagmåling, egne køllelengder, enkelt kølleforslag, søketimer, rundelagring, gjenopptakelse og historikk. Én spiller.
6. **Test og rett. Delvis utført.** Datapipelinen testes mot de faktiske råfilene. 38 Monkey C-tester rapporterer PASS i simulatoren, inkludert eksplisitt produksjonsrendering for alle 36 hull, zoom/pan-koordinater, native menyelementer/callbacks og faktisk Garmin-simulatorlagring. Strengidentitet i side-/menyruting er rettet; tidligere rendertester var for svake og er skjerpet. Startside er visuelt observert. Monkeydo returnerer likevel kode 1 etter PASS-rapporten; årsaken er uavklart. Berøringsflyt begrenses av gjentatt skjermmodus Off. Ingen fysisk klokkeverifikasjon hevdes.
7. **Installer og feltverifiser. Gjenstår.** Ingen Venu 2 var montert under `/Volumes`; appen er ikke overført til klokken. Kontroller skjermflyt og GPS ute på banen, lagring etter omstart og strømforbruk før bruk som primær avstandsmåler.

## Funksjonsdekning mot S72

| Funksjon | Status i denne versjonen | Hva gjenstår |
| --- | --- | --- |
| Valg av norsk bane | Bogstad og Bærum | Nærhetssortering, valgfri tee, 9/18-hullsvalg |
| Hovedskjerm og gul avstand | Implementert etter manual | Simulatorbilder og sammenligning med fysisk S72 |
| For-/bakkant og mål | Beregnet fra OSM-polygon/GPS | Feltkontroll; kartdata kan være gamle |
| Kart og zoomet green | Fargelagte baneflater, skog/trær, panorering ved draing og zoomknapper 1–8× | Sammenligning med fysisk S72; ingen pinch-API funnet |
| Flyttbart flagg | Trykk eller dra flagg inne på green, lagres for runden | Faktisk flagg må oppgis av spiller |
| Trepunkts mål / layup-prikker | Karttrykk og avstand til mål; 100/150/200/250 m | Gjeldende spillerposisjon krever fersk GPS |
| Driverbue | Vises når egen driver-carry er satt | Egen carry er ikke automatisk målt |
| Hindre | Nærliggende OSM-objekter med avstand til grense | Komplett, offisiell hinderliste ikke kjent |
| Hullbytte | Manuelt med meny/sveip | Automatisk hullgjenkjenning og veivisning |
| Score/putter/straff/fairway | Lokal registrering | GIR-beregning, flere spillere og scramble |
| Handicap/Stableford | Direkte oppgitt spillehandicap | Ingen automatisk WHS-teeomregning; ukjent indeks gir ukjent poengsum |
| Slagmåling | Manuell GPS-måling med køllevalg, gjenopptakelse, sletting og køllekorreksjon; glemte slag og putter kan registreres med ukjent avstand. Inntil 100 registreringer per runde | AutoShot, automatisk slagklassifisering og CT1/CT10-integrasjon |
| Køller | 14 køllevalg pluss ukjent, egne carry-verdier og rundens antall/snitt/lengste målte totalavstand | Historikkbasert spredning, læring og forventede slag |
| Caddie | Enkelt forslag fra avstand og egen carry | Garmins algoritme/historikk, vind/høyde, sannsynligheter |
| Vind/vær | Offentlig Weather-API, tidsmerket cache under 60 min | Fysisk verifikasjon, værstasjonens relevans for banen |
| Retning | Sann nordpeiling til mål, nord opp | Håndleddsorientert PinPointer/kompass |
| Søketimer | Tre minutter og engangs vibrasjonsvarsel mens appen kjører, også utenfor timersiden | Vibrasjon må prøves på Venu 2; timeren kjører ikke etter app-exit |
| Meter/yards og turneringsmodus | Lokale valg; caddie/peiling/driverbue slås av | Regelverkssertifisering ikke utført |
| Rundeoversikt/historikk | Lokal lagring, fortsett/lagre/forkast, og lesbar slaglogg per lagret runde; nye runder lagres hver for seg | Garmin Golf-synk, FIT, sky og eksport |
| Pause og gjenopptakelse | Gjenopptakelse etter app-exit | Separat pausetidtaking, turdistanse og steg |
| Store tall | Lagret skjermvalg med store for-/midt-/bakkantavstander; kart fra meny | Runtimekontroll av layout |
| PlaysLike | Ikke implementert | Terreng-/værmodell, datagrunnlag og original algoritme |
| Greenhelling / green reading | Ikke tilgjengelig | Høydedata med tilstrekkelig oppløsning og kildeavtale/API |
| Flyfoto | Ikke tilgjengelig | Bilder, lisens, offline-pakking og minneprøving |
| Svingmål / tempo / driving range | Ikke implementert | Sensorfrekvens, kalibrering, algoritme og validering på håndledd |
| Puttanalyse / puls mot prestasjon | Ikke implementert | Puttidentitet, datamodell og validert måling |
| Rangefinder/sensorparing | Ikke implementert | Offentlig kompatibel protokoll og reell utprøving |

## Konkrete blokkeringer for full leveranse

- Ingen autentisk S72-programvarefil: ingen REA-Evidence eller verifisert intern oppførsel.
- Garmin Golf-, AutoShot-, caddie- og medlemsfunksjoner har ikke vist tilgjengelig tredjepartsgrensesnitt i dette arbeidet. Tilgjengelighet er uavklart, ikke bevist umulig.
- Ingen surveyerte greenhellinger eller lisensierte flyfoto for de valgte banene.
- Simulator kan nå brukes, men berøringsflyt og launcher-avslutning er uavklart. Ingen tilkoblet fysisk Venu 2.

Det er derfor en byggbar prototype, ikke en fullført S72-port. Fullfør listen over gjenstående funksjoner først når de respektive datakildene, API-ene og verifikasjonsmiljøet er etablert.
