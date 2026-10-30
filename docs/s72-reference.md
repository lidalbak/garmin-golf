# Approach S72 reference investigation

Investigated 2026-10-16. Scope: authentic public S72 golf implementation; no account access, accepted agreements, target execution, or device modification. User owns Venu 2 only.

## Acquired artifact and provenance

- Official manual downloaded from https://www8.garmin.com/manuals/webhelp/GUID-91BDFC0A-876D-451A-AF8E-8DD63A4D6B85/EN-US/Approach_S72_OM_EN-US.pdf
- Local file: `reference/Approach_S72_OM_EN-US.pdf`, 138 pages.
- SHA-256: `8837a11a6fb6bfa37f2d630c7f8019ebae7469c880904f6ef3294c7ff277155a`.
- Manual pages 8-12 rendered to `reference/s72-manual-008.png` through `s72-manual-012.png`. Page 8 visually inspected. These are documentation, not software artifacts or runtime observations.

## Firmware search outcome

No authentic S72 firmware/app binary was obtained. Bounded public searches: `site.garmin.com Approach S72 software update download gcd`, `Approach S72 GUPDATE`, and `Approach S72 firmware download software Garmin`; official regional product/software pages and official update guidance reviewed. This does not establish that no public URL exists.

Official update guidance directs owners to Garmin Express/Garmin Golf and connected-device/Wi-Fi workflows:
https://www8.garmin.com/manuals/webhelp/GUID-91BDFC0A-876D-451A-AF8E-8DD63A4D6B85/EN-US/GUID-C2A77CD4-428F-42D9-8F1B-B4AD59F9821C.html
The Taiwan S72 product update section currently states that no update program is available:
https://www.garmin.com.tw/products/wearables/approach-s72-43-bronze/

REA binary analysis remains blocked by missing authentic target bytes. No Evidence ID, decompilation, runtime reproduction, original resources, or algorithm equivalence is claimed. An unrelated Garmin mobile/Express binary would not resolve this. The S72 firmware cannot be claimed installable on Venu 2. A future authorized S72 update file or device-owned firmware dump is the next useful input.

## Visual observation

Manual page 8 shows a round black face: centered hole/par heading; three distances in a left column, with large yellow middle distance and smaller white back/front distances; aerial/map depiction on right, flag at green, layup markers and driver-distance arc. This establishes a reference composition, not pixel-identical fonts/assets. Swipe on distances changes data; tap changes PlaysLike; tap map opens target/hazard detail; button opens menu. Automatic next-hole transition is documented.

## Golf coverage checklist (documentation-derived)

- Round start: GPS location, nearby course selection, 9/18-hole choice, scoring prompt, tee selection.
- Hole: back/middle/front distance, par/hole, driver arc, colored layups, hole map, target-distance measurement and zoom; next-hole navigation; manual hole/green switching.
- Green: shape, draggable flag valid for current round; subscription contours and putt line slopes; marking actual flag and putt positions.
- Caddie: club choices, dispersion and expected strokes; wind/history dependency and five-round activation; probability when dispersion overlaps green.
- Scoring: strokes/Stableford/scramble, handicap, two players, putts, penalties, GIR/fairway direction, prior-hole history.
- Shots: AutoShot, manual missed-shot addition, club prompt, club distance/accuracy history, custom targets.
- Utility: three-minute search timer, PinPointer, round time/distance/steps/HR, big numbers, metric/imperial, tournament restrictions; pause/save/discard/edit end flow; add back nine.
- Training/new S72: driving-range activity; hand-speed timeline, backswing clock position, wrist-rotation chart, swing-plane/transition angles, tempo ratio and tempo training.
- New S72 ecosystem: post-round HR/performance associations, putting analysis, subscription aerial imagery/green reading. Club sensors/rangefinder pairing and Garmin Golf/Connect transfers require independent compatibility evidence.

Primary cross-checks (each has independent explanation and conditions):
- Menu: https://www8.garmin.com/manuals/webhelp/GUID-91BDFC0A-876D-451A-AF8E-8DD63A4D6B85/EN-US/GUID-07681BF1-996F-4151-963B-B6D7CA7CF910.html
- Settings: https://www8.garmin.com/manuals/webhelp/GUID-91BDFC0A-876D-451A-AF8E-8DD63A4D6B85/EN-US/GUID-03AE9B05-F2B8-4C92-ADF2-94CC66AF85B3.html
- Caddie: https://www8.garmin.com/manuals/webhelp/GUID-91BDFC0A-876D-451A-AF8E-8DD63A4D6B85/EN-US/GUID-D47C2615-3F06-4B1A-BAB4-CE1B15039CF7.html
- Hazards: https://www8.garmin.com/manuals/webhelp/GUID-91BDFC0A-876D-451A-AF8E-8DD63A4D6B85/EN-US/GUID-622EE307-DA4A-4809-8C83-7E7B6BBF9826.html
- Green reading algorithm overview: https://www.garmin.com/en-GB/garmin-technology/golf-science/distance-measurement/green-reading/
- S72 launch/new capabilities: https://www.garmin.com/en-US/newsroom/press-release/outdoor/meet-approach-s72-garmins-ultimate-golf-smartwatch/
- Official introduction: https://forums.garmin.com/outdoor-recreation/golf/f/approach-s72/445597/approach-s72-introduction

## Implementation implications (inference, not REA findings)

A separately authored Connect IQ UI can reproduce reference composition and public workflows. Public OSM geometry can support Norwegian holes/hazards with explicit coverage limits. Accurate front/back requires green polygons; hole endpoint alone is only an approximate center. Real contours, aerial imagery licensing, native Garmin Golf synchronization, proprietary AutoShot/caddie models, high-rate calibrated swing metrics and sensor pairing remain separate unresolved capabilities. Show unavailable values explicitly; do not fabricate slopes, putting probabilities or measured swing metrics. Simulator success cannot establish Venu 2 physical behavior.
