# Dealership validation

Thirty factory builds were exercised with native Godot tests: configuration, purchase/equip behavior, exact currency deductions, duplicate rejection, progression locks, filters, collection pagination, and per-car save/load. Engine horsepower excludes electric assistance; SF90 assistance is separate.

| Model | Credits | Level | Factory box | Engine HP / Nm | kg | Bench quarter |
| --- | ---: | ---: | --- | ---: | ---: | ---: |
| Mazda MX-5 Miata | 0.0 | 1.0 | oem_miata | 116 / 136 | 1002 | 16.073 s |
| Honda Civic Si | 5,200.0 | 1.0 | oem_civic_si | 160 / 150 | 1180 | 15.924 s |
| Volkswagen Golf GTI VR6 | 6,000.0 | 1.0 | oem_gti_vr6 | 172 / 235 | 1280 | 15.119 s |
| Acura RSX Type-S | 8,500.0 | 1.0 | oem_rsx | 200 / 193 | 1260 | 14.712 s |
| Subaru BRZ | 10,500.0 | 1.0 | oem_brz | 200 / 205 | 1253 | 14.751 s |
| Acura Integra Type R | 15,000.0 | 1.0 | oem_integra | 195 / 176 | 1160 | 14.701 s |
| Volkswagen Golf GTI | 12,000.0 | 1.0 | oem_gti | 201 / 308 | 1375 | 14.752 s |
| Honda S2000 | 19,000.0 | 1.0 | oem_s2000 | 240 / 220 | 1286 | 13.828 s |
| Toyota GR86 | 18,000.0 | 1.0 | oem_gr86 | 228 / 249 | 1276 | 13.823 s |
| Nissan 350Z | 15,000.0 | 1.0 | oem_z350 | 287 / 371 | 1463 | 13.170 s |
| Toyota Supra Turbo | 33,000.0 | 2.0 | oem_supra | 320 / 427 | 1565 | 13.034 s |
| BMW M3 E46 | 26,000.0 | 2.0 | oem_m3 | 333 / 355 | 1549 | 12.988 s |
| Subaru WRX STI | 25,000.0 | 2.0 | oem_sti | 300 / 407 | 1480 | 13.107 s |
| Mitsubishi Lancer Evolution VIII | 24,000.0 | 2.0 | oem_evo | 271 / 380 | 1470 | 13.558 s |
| Honda Civic Type R | 28,000.0 | 2.0 | oem_type_r | 306 / 443 | 1417 | 13.726 s |
| Ford Mustang GT | 35,000.0 | 3.0 | oem_mustang | 480 / 563 | 1741 | 11.795 s |
| Toyota GR Supra 3.0 | 36,000.0 | 3.0 | oem_supra_gr | 338 / 547 | 1539 | 12.372 s |
| Chevrolet Camaro SS | 32,000.0 | 3.0 | oem_camaro | 455 / 617 | 1671 | 11.832 s |
| Volkswagen Golf R | 30,000.0 | 3.0 | oem_golf_r | 288 / 417 | 1530 | 12.811 s |
| Nissan Z Performance | 37,000.0 | 3.0 | oem_z400 | 400 / 525 | 1604 | 12.194 s |
| Chevrolet Corvette Z06 | 85,000.0 | 4.0 | oem_z06 | 670 / 623 | 1661 | 10.684 s |
| Nissan GT-R NISMO | 100,000.0 | 4.0 | oem_gtr | 600 / 677 | 1752 | 11.000 s |
| Audi R8 V10 Performance | 105,000.0 | 4.0 | oem_r8 | 611 / 580 | 1670 | 10.814 s |
| Ford Mustang Shelby GT500 | 75,000.0 | 4.0 | oem_gt500 | 760 / 847 | 1892 | 10.608 s |
| Dodge Challenger SRT Hellcat Redeye | 68,000.0 | 4.0 | oem_redeye | 797 / 959 | 2050 | 10.763 s |
| Porsche 911 Turbo S | 145,000.0 | 5.0 | oem_turbo_s | 640 / 895 | 1640 | 10.458 s |
| McLaren 765LT | 190,000.0 | 5.0 | oem_mclaren | 755 / 800 | 1388 | 10.017 s |
| Ferrari SF90 Stradale | 240,000.0 | 5.0 | oem_sf90 | 769 / 800 | 1770 | 9.781 s |
| Dodge Challenger SRT Demon 170 | 115,000.0 | 5.0 | oem_demon | 1025 / 1281 | 1941 | 9.479 s |
| Bugatti Chiron | 500,000.0 | 5.0 | oem_chiron | 1479 / 1745 | 1995 | 9.530 s |

The tuned GR86 fixture ran 10.542 s versus 10.814 s for the stock R8. This verifies one affordable-build comparison, not universal superiority over expensive cars.

These are simulation results, not manufacturer-certified performance. See ROSTER_REPORT.md for specification provenance, artwork limitations, class differences, reference gaps, and device testing still required.
