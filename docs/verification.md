# Verifikasjon — 16. oktober 2026

## Gjeldende status

- Venu 2-app og testprogram bygger med installert SDK 9.1.0 og gradvis typesjekk nivå 1. Dynamiske typeadvarsler gjenstår.
- `build/verified-runtime-tests.log` rapporterer 38 PASS, ingen feil. Garmins launcher returnerer likevel kode 1 etter PASS-rapporten; dette holdes synlig som uavklart feil.
- Produksjonskart og greener for alle 36 hull er nå kjørt med eksplisitt kontroll av at karttransformasjonen faktisk ble etablert. Zoom 1,5×, panorering og transformasjon tilbake til koordinat er kontrollert i Garmin-runtime.
- Ekte `Application.Storage` er testet gjennom produksjonsmodellen: pågående slag og score lagres, ny modellinstans gjenopptar, slag fullføres, 100 slag arkiveres og leses tilbake. Unike testnøkler per kjøring brukes og ryddes etter testen; dette er simulatorlagring, ikke fysisk klokke eller verifisert prosessomstart.
- Native Menu2-elementer og deres produksjonscallbacks er testet: dynamisk rutenavn, banevalg, gå til green, menydybde og tilbake. Testen bruker selve menyelementene og kaller input-delegaten direkte; den bekrefter ikke et muse-/touch-event fra operativsystemet.
- Ni datakontroller består mot faktiske OSM-råfiler og produksjonspipeline.
- Startside er visuelt observert. Designbildene er fortsatt separate forhåndsvisninger.

## Funnet og rettet under testing

Side- og menyruting brukte strengidentitet (`==`) i stedet for innhold (`equals`). Test med kartzoom fant null transformasjon fordi den forespurte kartvisningen ikke ble tegnet. Sammenligningene er rettet i hele meny-/visningslaget, inkludert kameraskifte. De tidligere rendertestene kunne passere uten å nå kartgrenen, og løkken valgte dessuten relativt hull i stedet for absolutt hull. Testene velger nå alle 36 hull eksplisitt og krever etablert karttransformasjon. Eldre PASS-rapporter under er historiske og etablerer ikke denne dekningen.

Startsiden åpner nå banemenyen direkte fra Velg bane, og treffområdet følger knappen. Midlertidig tap-logging er fjernet fra leveransen.

## Gjenstår

- Museklikk via datamaskinverktøyet ga ikke bekreftet tap-hendelse i diagnostisk appbygg. Simulatorens gjentatte Off-status er ikke løst. Ingen fysisk berøringsflyt, faktisk flaggdrag eller komplett ende-til-ende-betjening hevdes.
- Fersk/gammel GPS-hendelse fra simulator, vær, biometriske data og feltavstander er ikke ende-til-ende-testet.
- Ingen Venu 2 er tilkoblet: installasjon, app-/klokkeomstart, batteri, faktisk minnetopp og bruk på banen gjenstår.
- Ingen original S72-app/fastvare er analysert med REA. Ingen feltverifisering av OSM eller medlemsbasert green-/flyfotodata.

## Historiske kontrollnotater

## Simulatoroppstart 16. oktober 2026

Connect IQ-simulatoren kunne nå åpnes via den installerte ConnectIQ.app. `python3 scripts/build.py --run` bygget og lastet appen for Venu 2 (5.0.0). Simulatorens skjermmodus stod på Off; etter valg av High Power ble appens startside synlig med Golf App, Bogstad/Bærum og Velg bane. Dette bekrefter oppstart og første rendering i simulator. Navigasjon, banekart, GPS, lagring og de native testene er ikke verifisert av denne oppstartskontrollen. Skjermen gikk senere tilbake til Off.

## Simulator: funksjons- og rendertester

35 native tester er kjørt i Garmin-simulatoren for Venu 2 (API 5.0.0). Resultat: `PASSED (passed=35, failed=0, errors=0)`, se `build/final-simulator-tests.log`. De to nye rendertestene bruker produksjonsvisningene og faktiske baneressurser: hovedkart og green for alle 36 hull, samt score og store tall med kjent testposisjon. Dette kontrollerer at tegnekoden kjører, ikke visuell riktighet eller berøringsflyt. Settings-testen dekker eldre data uten bigNumbers, lagring/gjenlesing og feil type.

Garmins monkeydo avslutter med kode 1 etter den komplette PASS-rapporten i de to siste kjøringene. Byggskriptet bevarer denne feilen; årsaken er uavklart. Ikke tolk hele kommandoen som en ren vellykket prosess.

Kildekontroll av startsidens handling viste at Velg bane åpnet generell meny og at berøringsfeltet ikke samsvarte med knappen. Den åpner nå banemenyen direkte og bruker knappens faktiske grenser. Endringen er bygget, men fortsatt ikke bekreftet ved synlig berøringsnavigasjon. Simulatoren går gjentatte ganger til skjermmodus Off under interaksjonsforsøk. Ingen feil i appens menyflyt eller løsning på skjermtilstanden hevdes. Fysisk GPS, drag/zoom, skuddregistrering via UI og virkelig enhetslagring er fortsatt ikke ende-til-ende-verifisert. Modelltestenes lagringsfeil bruker en testadapter.
