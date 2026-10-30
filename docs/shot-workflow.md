# Meny, køller og slag

Implementert og kompilert for Venu 2. Berøring, menystakk og lagring er ikke verifisert i Garmin-runtime ennå. [Designvisningen](shot-preview.png) bruker eksempeldata; venstre skjerm er en menyskisse, ikke en avlesning av SDK-ets faktiske Menu2-rendering.

## Under en runde

Golfmenyen følger rekkefølgen i S72-manualen der funksjonene finnes: vis green/kart, kølleforslag, bytt hull, scorekort, mål slag, slaghistorikk/køllestatistikk, søketimer, rundeinformasjon, innstillinger og avslutt runde. Undermenyer har vanlig tilbake-navigasjon. Verktøy for vind, peiling og kartobjekter ligger under innstillinger.

## Registrer et målt slag

1. Stå ved ballen og åpne **Mål slag**.
2. Velg **Start nytt slag**, deretter kølle. **Ukjent kølle** er tillatt. En fersk GPS-posisjon er nødvendig for å starte.
3. Skjermen viser valgt kølle og løpende avstand fra startpunktet. Mister klokken fersk GPS, vises ukjent avstand frem til en ny posisjon finnes.
4. Gå til ballen og velg **Fullfør slag**. Skjermen viser avstand og kølle, og lar deg åpne **Rediger** eller starte neste slag.

Et målt slag er GPS-forflytning, ikke en målt ballbane eller carry. Rull, GPS-feil og spillerens plassering påvirker målingen. AutoShot og automatisk svingdeteksjon er ikke implementert.

En pågående måling beholder startpunkt, opprinnelig hull og kølle ved hullbytte og gjenopptakelse. Et senere køllevalg for neste slag endrer ikke målingens kølle. **Bytt kølle for målingen** er en egen eksplisitt handling. **Avbryt målingen** krever bekreftelse og lager ikke en falsk slagregistrering.

## Rett, legg til og se historikk

- **Slag på dette hullet** og **Alle slag i runden** viser nyeste registrering først. Hver registrering har en stabil identitet, slik at sletting ikke flytter en senere korreksjon over på et annet slag.
- På et aktivt slag kan køllen endres, eller registreringen slettes etter bekreftelse. En GPS-observasjon blir ikke erstattet av en oppdiktet avstand.
- **Legg til glemt slag** og **Registrer en putt** fungerer uten GPS-måling. Manglende avstand beholdes som ukjent, ikke null meter.
- Lagrede runder har en lesbar slaglogg. De åpnes kun for visning. Nye arkiver bevarer køllenavnene fra runden; eldre logger som mangler navn, viser den beholdte kølleidentiteten.
- Scorekortet er separat. Registrering, sletting eller korrigering av et slag endrer ikke automatisk totalscore eller antall putter.

## Køller og statistikk

Driver, 3 wood, hybrid, 4–9 jern, PW/GW/SW/LW og putter er tilgjengelige. Den gamle baggens ti plasser beholder identitet og lengder ved oppgradering; visningsrekkefølgen er separat fra lagrede kølle-ID-er. Egen carry har ingen forhåndsutfylte antatte lengder.

Køllestatistikk viser registrert antall, målt antall, snitt og lengste GPS-avstand i den aktive runden. Manuelle registreringer uten målt avstand teller ikke som null i snittet. Disse avstandene overskriver ikke spillerens egen carry.

## Lagring og feil

`GolfShotLog` eier tolkning av både eldre slag-arrays og den nye kompakte versjonen. UI-et bruker de parsede faktaene. Lagring versjon 2 bevarer stabile slag-/runde-/kølle-ID-er, eksplisitte ukjente verdier og en pågående målings opprinnelige tilhørighet. Det aktive lagringsnøkkelnavnet beholdes for kompatibilitet; en gammel gyldig runde konverteres først når den lagres.

Nye arkiver har én komplett lagret verdi per runde og en liten historikkindeks. Historikk skrives før aktiv runde frigjøres. Delvis feil kan prøves igjen uten duplikatarkiv. Feil ved sletting av et utgått arkiv beholder oppryddingsansvaret i den lagrede indeksen. Gamle historikkdata overskrives ikke under innlesing.

Inntil 100 slagregistreringer beholdes per runde. En pågående måling reserverer en plass. Faktisk lagringskapasitet er enhetsavhengig; ved full lagring blir endringene beholdt i minnet, en tydelig feil vises, og **Prøv lagring på nytt** er tilgjengelig. En feilet lagring rapporteres ikke som vellykket.
