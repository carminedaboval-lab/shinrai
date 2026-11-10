# Real police body-worn cameras: technical fact sheet for a game bodycam mode

Research date: 2026-11-08. Sources favour manufacturer spec sheets (2023–2026), the DHS SAVER market survey (Jan 2024, product data gathered Dec 2021–Oct 2023), Axon help-centre docs, and Force Science / Police1 / Amped analyses. Older models are marked. Watermark details are described generically (the game uses an invented brand).

---

## 1. Current models: FOV, aspect, resolution, frame rate, sensor, low light, WDR/HDR, EIS, codec/bitrate

### Takeaway
Current police bodycams cluster tightly: **16:9 (Axon Body 4 also offers 4:3), 1080p mainstream (1440p on Axon Body 4, 4K output on Getac BC-04), 30 fps (25 fps in PAL markets), H.264 in MP4, roughly 2–12 Mbps, ~120–140° horizontal / 63–93° vertical / 140–165° diagonal FOV, colour low light rated at 0.035–0.2 lux, usually no stabilisation.** The published H/V/D angles fit a fisheye-type (roughly equidistant or equisolid) projection, not a rectilinear one (see section 2).

### Cited Findings

**Spec table (manufacturer and DHS figures as published)**

| Model (status) | FOV H / V / Diag | Aspect | Max res / options | fps | Low light | Codec | Source |
|---|---|---|---|---|---|---|---|
| Axon Body 4 (current, launched 2023) | 16:9: ~140° / 76° / ~160°; 4:3: 127° / 93° / ~160° | 16:9 or 4:3 | 1440, 1080, 720, 480 | 30 | <0.1 lux, "motion blur correction" | "MPEG4" | [Axon](https://www.axon.com/resources/how-axon-body-cameras-bridge-the-gap); [AB4 card](https://cdn.mediavalet.com/usva/axon/lRL_NrK760OIbgl2z9W-bA/ixJhWEJZgU2E2WMqwDxsOw/Original/Axon%20Body%204%20Product%20Card%20Enterprise%20EN_GB.pdf); [Axon comparison](https://a.storyblok.com/f/133181/x/5d21d52e94/ab2-ab3-ab4-comparison.PDF); [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf) |
| Axon Body 3 (2019, still widely fielded) | 125.2° / 68.6° / 146.4° | 16:9 | up to 1080 (1080/720/480) | 30 | better than 0.1 lux, motion blur correction | not stated | [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf); [Axon comparison](https://a.storyblok.com/f/133181/x/5d21d52e94/ab2-ab3-ab4-comparison.PDF) |
| Axon Body Mini (AX1047, spec rev. Sep 2026) | 125.2° / 68.6° / 146.4° | 16:9 | 1080H 1920×1080; 720H/720L 1280×720 (720H default); 480p 854×480 | up to 30 | <0.1 lux, automatic motion blur correction | MPEG-4, H.264 | [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf) |
| Axon Body 2 (older, ~2016) | 118.6° / 63° / 143° | 16:9 | up to 1080 | up to 30 | <0.1 lux | — | [Axon Body 2 spec sheet](https://axon-2.cdn.prismic.io/axon-2/93a03ad8-7a59-4afc-807d-76b2daa92017_Spec+Sheet+-+Axon+Body+2+-+ENG+-+UK.PDF) (via search excerpt); [Axon comparison](https://a.storyblok.com/f/133181/x/5d21d52e94/ab2-ab3-ab4-comparison.PDF) |
| Motorola V700 (current, datasheet 07-2024) | 130° / 73° / 149° | 16:9 | 1920×1080, 1280×720, 864×480 | 30, 15, 10, 5 (agency-configurable) | 1080p sensor, <0.1 lux; has an HDR mode | H.264 High Profile | [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf) |
| Motorola V300 (ex-WatchGuard line, older but fielded) | 130° / 73° (vertical window adjustable +15° / −20°) | 16:9 | 1920×1080, 1280×720, 864×480 | 5–30 | 4K sensor used for "digital turret", records max 1080p; 0.035 lux | H.264 High Profile, AAC audio | [V300 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v300-datasheet.pdf) (via search excerpt); [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf) |
| Motorola VB400 (current, datasheet 09-2026; ex-Edesix, security/UK police) | 120° / 65° / 140° | 16:9 | 1920×1080, 1280×720, 640×360 | 25 or 30 | to 0.2 lux | H.264 | [VB400 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/vb400-datasheet-na.pdf) |
| Getac BC-04 (current, sheet Jan 2025) | 140° / — / 158° | ~16:9 | 3600×2024 ("4K"), 2560×1440, 1920×1080, 1280×720 | 30 | "ZeroDark", HDR | MP4 (H.264), H.265 | [Getac BC-04 sheet](https://www.getac.com/content/dam/getac/all-sites-img/Getac_BC-04_Product_US_250116.pdf) |
| Getac BC-03 (older) | — / — / 165° | — | 1080 | 30 | — | H.264 (H.265 some cases), AAC | [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf) |
| Reveal D6/D7, K6/K7 (UK/EU common) | configurable 90–120° / 50–60°; ~150° diag | — | 1080 | 25–30 | 0.05 lux at 30 fps | H.264 (K-series also H.265), MP4 | [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf) |
| i-PRO BWC4000 | 16:9: 137° / 79°; 4:3: 115° / 87°; ~157° diag | 16:9 or 4:3 | 1200 | 30 | 0.08 lux, colour and B/W modes; **6-axis gyro stabilisation** | H.264, AAC, MP4 | [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf) |

- Axon Body 4 has a 5 MP sensor; the 4:3 / 160° mode "increases visibility by 39%". — [AB4 card](https://cdn.mediavalet.com/usva/axon/lRL_NrK760OIbgl2z9W-bA/ixJhWEJZgU2E2WMqwDxsOw/Original/Axon%20Body%204%20Product%20Card%20Enterprise%20EN_GB.pdf)
- Axon Body 4 has an agency setting for body-camera FOV: 160° (wider) or 120° (longer battery); the Flex POV module recommends 120°. — [Axon AB4 settings](https://www.axon.com/help/axon-body-4/cameras-and-sensors/body/settings.htm); DHS gives AB4 as "agency configurable 120°–160° diagonal". — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Axon's stated pixel density for AB4: ~14 pixels per degree at 1080p, 9 at 720p, 6 at 480p, against ≥60 PPD for the human fovea; the camera re-adapts to dark/bright "typically in a second or so". — [Axon](https://www.axon.com/resources/how-axon-body-cameras-bridge-the-gap)
- Axon Body 3 and Body 4 use a "fixed focus, all-glass lens". — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- V700 lists "Dewarping: Vertical dewarping (removes fisheye effect)" and a 6-axis accelerometer/gyroscope marked "hardware ready"; its battery figure is quoted with HDR disabled, confirming an HDR mode exists. — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf)
- Electronic stabilisation is the exception: Pro-Vision Bodycam 4 advertises EIS and i-PRO BWC4000 6-axis gyroscopic stabilisation; Axon/Motorola/Getac/Reveal entries list none. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- IR illuminators / B&W night modes exist mainly on budget brands (LensLock Genesis, Sentinel Protector II, WOLFCOM: IR LEDs, ~10 m face detection; Digital Ally FirstVu Pro: ~5 m; Kustom Vantage day/night switch). Axon, Motorola, Getac entries list no IR. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- DHS notes lux ratings are not objective ("acceptable image" is subjective), and that some BWCs exceed the human eye's low-light sensitivity. 30 fps is the common rate; all surveyed BWCs are progressive scan. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Storage tables (basis for bitrate inferences below): Axon Body Mini 480p 0.9 GB/h, 720L 1.2 GB/h, 720H 2.0 GB/h, 1080H 4.5 GB/h. — [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf). V700 128 GB = 28 h 1080p / 55 h 720p / 110 h 480p. — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf). V300 128 GB = 23 h 1080p; Reveal D6/D7 64 GB = 20 h 1080p / 68 h 480p; Kustom Argus 64 GB = 12 h 1080p30 / 28 h 720p30. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Axon Body Mini battery spec reads "12 hours at 720P, buffering and recording 5fps/30fps". — [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf)
- The Axon Body 4 Flex POV module replaces the main camera view when attached; detaching reverts to the chest camera. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)

### Inferences
- **Approximate bitrates (total file incl. audio), from storage tables:** Axon Mini 1080H ≈ 10 Mbps, 720H ≈ 4.4 Mbps, 720L ≈ 2.7 Mbps, 480p ≈ 2.0 Mbps; V700 1080p ≈ 10 Mbps, 720p ≈ 5 Mbps, 480p ≈ 2.6 Mbps; V300 1080p ≈ 12 Mbps; Reveal 1080p ≈ 7 Mbps; Argus 1080p30 ≈ 12 Mbps, 720p30 ≈ 5 Mbps. Agency default on Axon Mini is 720H (~4.4 Mbps). Game default: **1280×720 internal look, ~4–5 Mbps-equivalent compression, 30 fps**; "high" preset 1080p ~10 Mbps.
- The Axon Mini "5fps/30fps" line suggests buffering may run at a reduced frame rate (5 fps) and recording at 30 fps; not confirmed by Axon docs found here. V700 also allows 5–15 fps agency configs. A choppy low-fps pre-event segment is plausible but unverified.
- 3600×2024 for the Getac "4K" output is a non-standard width (not 3840), consistent with a crop/dewarp of a fisheye sensor image.
- Axon's 14 PPD at 1080p equals 1920 px / ~140° horizontal, i.e. pixels are spread roughly evenly per degree across the frame (a fisheye-type mapping; see section 2).
- Motorola acquired WatchGuard (2019) and Edesix; V300/4RE lineage is WatchGuard and VB400 is Edesix. Background knowledge, not sourced in this pass.

### Gaps
- No vendor names the sensor part, size, or confirms CMOS rolling shutter; no published readout times.
- No official bitrate figures; values above are derived from storage tables (GB vs GiB and file overhead ignored).
- Axon Body 4 Flex POV module FOV figures were not found (only the "120° recommended" setting).
- Axon WDR/HDR status is not stated in any Axon document found. Getac lists HDR; V700 implies HDR.
- Reveal's current D-series datasheet (vs. DHS 2023 data) was not retrieved.

---

## 2. Lens projection: fisheye vs rectilinear, barrel distortion, edge stretch, distance misjudgement

### Takeaway
The published angles prove bodycams use **fisheye-type wide-angle lenses, not rectilinear ones**: for a rectilinear lens, 130° H in 16:9 would imply ~101° V and ~132° D, yet Motorola publishes 130° / 73° / 149°, which matches an **equidistant (f-theta) projection**. Expect strong barrel distortion (straight lines bow outward), objects in the centre looking magnified and close, edges compressed, and distance/time perception distorted.

### Cited Findings
- V700: 130° H / 73° V / 149° D. — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf). AB4: ~140° H / 76° V (16:9) and 127° H / 93° V (4:3), both ~160° D. — [Axon](https://www.axon.com/resources/how-axon-body-cameras-bridge-the-gap). AB3/Mini: 125.2° / 68.6° / 146.4°. — [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf). VB400: 120° / 65° / 140°. — [VB400 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/vb400-datasheet-na.pdf)
- Motorola calls the V700's correction "vertical dewarping (removes fisheye effect)", i.e. the vendor itself calls the raw image fisheye. — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf)
- Police1 / Critical Incident Review (Sgt. Jamie Borden, ret., Aug 2024) compared an Axon Body 4 against a 50 mm lens (~40–45° H, close to human central vision): the wide-angle bodycam lens stretches objects at frame edges, makes straight lines curve, and "significantly misrepresented" distance. In their demo the officer looked further from the threat than he was (subjects at 12 ft and 22 ft; a runner at ~14–15 ft). The article also says distortion "can make objects appear closer"; the two claims are not reconciled. — [Police1](https://www.police1.com/officer-safety/uncovering-the-hidden-distortions-in-body-worn-camera-footage)
- Critical Incident Review: looming plus fisheye distortion can significantly change the perceived speed and distance of moving objects; what looks close because of lens curvature could be further away. — [Critical Incident Review](https://criticalincidentreview.com/video-distortions-visual-principles-force-analysis/) (via search excerpt)
- Force Science (2014): cameras record in 2-D and lenses can "compress distances between objects or make them appear closer than they really are". — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)
- Amped Software: in barrel distortion straight lines curve outward from the centre; distortion grows toward the edges and is weaker near the centre; subjects near edges can look thinner, with narrower faces. — [Amped blog 2021](https://blog.ampedsoftware.com/2021/02/02/lens-distortion-cameras-may-change-the-shape-of-things). Facial distortion depends on subject-to-camera distance and cannot be fixed by software. — [Amped blog 2015](https://blog.ampedsoftware.com/2015/06/24/body-worn-cameras-bwcs-as-a-silver-bullet-vol-2-quality-2); [Amped calibration 2025](https://blog.ampedsoftware.com/2025/07/02/how-to-correct-lens-distortion-camera-calibration-in-amped-five)
- Amped now offers grid-based camera calibration specifically promoted for bodycams, dashcams and action cams. — [Amped calibration 2025](https://blog.ampedsoftware.com/2025/07/02/how-to-correct-lens-distortion-camera-calibration-in-amped-five)

### Inferences
- **Projection fit (my calculation from published angles):**
  - Equidistant model (r ∝ θ, so H:V angle ratio = aspect ratio and D ≈ √(H²+V²)): V700 130/73 = 1.78 = 16:9 exactly; √(130²+73²) = 149.1° vs 149° published. AB4 16:9 √(140²+76²) ≈ 159° vs ~160°.
  - Equisolid model (r = 2f·sin(θ/2), slightly more edge compression): AB3/Mini gives a predicted diagonal of ~146.8° vs 146.4° published; VB400 predicted ~139.8° vs 140°.
  - Rectilinear predictions are far off (V700 would be ~101° V / ~132° D).
  - **Game recipe:** render a wide rectilinear (or cubemap/panini) source, then apply a radial remap to equidistant or equisolid at ~130–140° H for 16:9. Default suggestion: equidistant, 135° H × 76° V, 16:9; optional 4:3 at 127° × 93°. Engine FOV alone (rectilinear) will look wrong; the warp is what sells "bodycam".
- Look of the warp: verticals near the left/right edges bow outward (barrel); the horizon bows when the camera pitches; centre subjects look large and near; anything within ~1 m of the lens (hands, pistol, door frames) balloons. People at the frame edge look thin and compressed, the opposite of rectilinear wide-angle edge stretching. Police1's "stretch at edges" wording conflicts with equidistant behaviour; treat it as describing perceived oddness rather than measured magnification.
- Distance: with ~14 px/deg and fisheye compression, a person at 7 m covers only a few dozen pixels in height. Distant threats look small and far while near objects loom, which suits gameplay tension.

### Gaps
- No vendor publishes distortion coefficients or the projection model; the fit above is inferred from H/V/D numbers.
- No measured Force Science distance-misjudgement data was found; the Police1 piece is qualitative.

---

## 3. Mounting: positions, lens height, agency preferences

### Takeaway
**Centre chest (sternum, on a shirt clip, magnetic or MOLLE mount on the vest) is the default**, with shoulder/epaulette, chest harness, and head/glasses/helmet (via tethered POV modules) as alternatives. Chest mounts are easy and stable, but the officer's own arms, hands and weapon block the lens, and the view sits below eye line. Head/glasses mounts track gaze but suffer face/brim obstruction and shake.

### Cited Findings
- DHS: cameras may attach to "shirt front, hat, helmet, glasses, or arm" via clip, harness, lanyard, headband, armband, magnetic mount or MOLLE; split units put the battery on the belt and the camera head on the chest. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Motorola V700 mounts: magnetic, heavy-jacket magnetic, MOLLE locking, Tek-Lok belt, shirt clip, heavy-jacket clip; marketing photos show centre-chest placement. — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf)
- Motorola VB400 (Klick Fast system): epaulette dock, radio-loop dock, 3- and 4-point chest harness, shoulder harness, crocodile clip, MOLLE vest dock; photos show chest-pocket and shoulder-strap (upper-chest) placement. — [VB400 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/vb400-datasheet-na.pdf)
- Getac BC-04 mounts: magnetic, double magnetic, alligator clip, MOLLE, pocket, swivel, action-camera, universal. — [Getac BC-04 sheet](https://www.getac.com/content/dam/getac/all-sites-img/Getac_BC-04_Product_US_250116.pdf)
- Axon Body 4 Flex POV: tethered module for "head mounted, shoulders, or in-hand for viewing around corners". — [AB4 card](https://cdn.mediavalet.com/usva/axon/lRL_NrK760OIbgl2z9W-bA/ixJhWEJZgU2E2WMqwDxsOw/Original/Axon%20Body%204%20Product%20Card%20Enterprise%20EN_GB.pdf). Axon sells an Oakley Flak 2.0 glasses mount "for eye-level recording". — [Axon Flex POV Oakley guide](https://cdn.mediavalet.com/usva/axon/eyX2ZM3ESEqqIahc5UXMDg/MXHbVfFoK0q1AQgzp57Ctw/Original/Axon%20Flex%20POV%20Oakley%20Flak%202%20Mount%20Installation%20Guide%20EN_US.pdf). Axon says the POV can attach to glasses or a helmet to better align with the officer's view. — [Axon](https://www.axon.com/resources/how-axon-body-cameras-bridge-the-gap)
- Reveal D/K series have an articulated camera head allowing head mounting; Reveal sells shoulder, magnet, shirt-clip, harness and helmet mounts. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Force Science: the camera does not follow the eyes; the officer's body "from nose to hands" can block the lens; a chest camera may capture little beyond extended arms when firing a gun or Taser. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)
- Police1/Borden recommends measuring lens height for comparisons and acknowledges the eyeline-vs-body-camera height difference. — [Police1](https://www.police1.com/officer-safety/uncovering-the-hidden-distortions-in-body-worn-camera-footage)
- A CNA (BJA TTA) mounting guide lists head, shoulder and chest options and advises trialling them on officers of different builds. — [CNA mounting graphic](https://www.cna.org/files/JRI-TTA/BWC/Officer-Mounting-Graphic.pdf) (via search excerpt)

### Inferences
- **Lens height (labelled default, not from a source):** a sternum mount on an average adult sits ~1.30–1.45 m above ground, ~25–35 cm below the eyes; a shoulder/epaulette mount ~1.45–1.55 m; glasses ~1.60–1.70 m. Game default: **1.38 m, 5–10° downward tilt, offset 0–4 cm left of centre (radio mic usually sits on a shoulder)**.
- A chest camera moves with the torso, not the head. Turning the head reveals nothing new; the view swings only when the whole body rotates. Each footstep produces vertical bob and a slight roll. Two-handed weapon presentation puts forearms, hands and slide/rear sight into the bottom-centre of the frame, often blocking it.
- Vests and seated (in-car) postures tilt the camera up (sky or car roof) or down (steering wheel, lap). Jacket flaps and seatbelts partially occlude the lens.
- Agencies prefer chest mounts for simplicity, stability and a consistent field of view; head/POV mounts are niche (SWAT, motor units). This rationale is inferred from vendor defaults; no agency survey was found.

### Gaps
- No measured lens-height statistics or agency mount-share surveys were found.
- An agency report quoted in trade press (that ~50% of video was obstructed by the face with older head mounts) could not be traced to a primary source.

---

## 4. Image artefacts

### Takeaway
Bodycam footage is defined less by resolution than by **unstabilised torso shake, rolling-shutter skew/wobble, motion blur in low light, slow auto-exposure with blow-outs or blank-outs in light transitions, low-bitrate H.264 smearing and blocking, and fisheye warp**. Low light on Axon/Motorola stays in colour (noisy, with blur correction), not IR monochrome.

### Cited Findings
- Rolling shutter is named as the root cause of "jello cam, wobble cam, skew, fluorescent light banding, partial exposure" in law-enforcement cameras; shaky input, low bitrates and wide-angle views combine to produce low-quality video. — [Forensic VR, Medium](https://medium.com/forensic-vr/rolling-shutter-problems-and-solutions-for-law-enforcement-cameras-part-1-9d8bddb35d4b) (via search excerpt; page returned 403; consultant opinion, not peer-reviewed)
- Amped (Matthew Cook, 2015): movement causes rolling-shutter distortion; pursuit footage is "very shaky"; wide-angle warping complicates analysis. — [Amped blog 2015](https://blog.ampedsoftware.com/2015/06/24/body-worn-cameras-bwcs-as-a-silver-bullet-vol-2-quality-2). Shakiness is a "common occurrence" with body-worn, helmet and handheld cameras. Amped also handles variable-frame-rate recordings from Wi-Fi or body-worn cameras. — [Amped FIVE update 2025](https://blog.ampedsoftware.com/2025/06/19/amped-five-update-37757-writing-queue-camera-calibration-riff-viewer-timing-source-for-video-writer-and-much-more) (via search excerpt)
- Low-light motion blur: longer integration times in low light produce more motion blur and make stabilisation harder. — [US patent 9692972, "Stabilization of low-light video"](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9692972) (general camera science, via search excerpt)
- Axon markets "motion blur correction" with low light on Body 3/4 and "automatic motion blur correction" on Body Mini, and Axon says Body 3 has "reduced motion blur and improved low-light performance". This implies motion blur is a known bodycam problem. — [Axon comparison](https://a.storyblok.com/f/133181/x/5d21d52e94/ab2-ab3-ab4-comparison.PDF); [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf)
- Exposure transitions: during bright-to-dim or dim-to-bright changes a camera "may briefly blank out images altogether"; in steady low light the camera can see more than the officer. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/). Axon says AB4 adapts "typically in a second or so" vs 30+ min for full human dark adaptation. — [Axon](https://www.axon.com/resources/how-axon-body-cameras-bridge-the-gap)
- Camera processing adjusts exposure, white balance, contrast and colour; encoding can change perceived distance, motion and speed. — [Police1](https://www.police1.com/officer-safety/uncovering-the-hidden-distortions-in-body-worn-camera-footage)
- Force Science: brief events (muzzle flash, knife glint) can fall between frames even at bodycam frame rates. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)

### Inferences (game-ready defaults; not sourced numbers)
- **Shake:** derive from player locomotion. Walking gives ~1.8–2 Hz vertical bob, a few cm amplitude, plus roll ±1–2°. Running doubles amplitude and adds random jolts. No EIS by default; an optional "EIS" toggle would crop ~10% and smooth.
- **Rolling shutter:** top-to-bottom row delay of ~15–30 ms per frame (typical for small CMOS sensors). Fast yaw skews verticals; impacts and running produce jello wobble; LED/fluorescent light can show horizontal banding.
- **Motion blur:** shutter tied to light level. Daylight is crisp (short shutter, slight stutter at 30 fps). At night expect ~1/30 s, so long smears on any pan and streaked headlights.
- **Auto-exposure:** asymmetric adaptation, ~0.5–1.5 s to settle (Axon "a second or so"). Stepping from night into a lit room overexposes to near-white, then pulls down; daylight into a dark doorway crushes to black for ~1 s. Highlights clip hard (white sky, white headlights with bloom); WDR/HDR gives slightly flat, haloed tonality. Use a mild HDR "local tone-map halo" option.
- **Noise:** in low light, luma grain plus chroma blotches, temporally denoised (smeary ghosting on moving objects). Keep colour at night but desaturate and green/teal-shift under sodium/LED streetlights. Axon/Motorola have no IR monochrome; IR mono is a "budget brand" option only.
- **Compression:** 720p at ~4–5 Mbps H.264 30 fps, keyframe every ~1–2 s (GOP length not sourced). Fast motion and foliage cause blocking/smearing; dark areas posterise into 8×8/16×16 blocks; a keyframe "pulse" refreshes detail each GOP.
- **Sharpening:** visible edge halos (in-camera sharpening plus upscale) and slightly oversharpened, crunchy text.
- **Lens:** chromatic aberration and softness toward corners; mild vignetting; flare/ghosting from streetlights and headlights; rain droplets or smudges on the small front window cause a soft glow patch.
- **Frame-level:** 30 fps capture with occasional dropped/duplicated frames (variable frame rate is common in bodycam files per Amped).

### Gaps
- No primary measurements (readout time, shutter ranges, GOP length, noise levels) for any police model.
- No source covered sharpening halos, flare, lens dirt or chroma noise specifically for bodycams; those items are inference.

---

## 5. On-screen overlays and watermarks

### Takeaway
The typical overlay is a **burned-in timestamp plus device identifier in the top-right corner**, continuously updating per frame, in local time or UTC by agency setting. Axon adds a "MUTED" flag when audio is muted. Evidence software may add a separate static "Recorded On" overlay on playback or export. Getac supports Date/Time/Officer ID stamps.

### Cited Findings
- Axon Body 4 watermark setting: "Adds a permanent watermark with date, time, and camera serial number to the upper-right corner of videos"; a time-zone option uses agency local time, otherwise UTC; "Watermark Audio Mute" shows **MUTED** when the user mutes audio. — [Axon AB4 settings](https://www.axon.com/help/axon-body-4/cameras-and-sensors/body/settings.htm)
- Axon Evidence: the watermark is embedded in the image, shows the camera's reference time for each frame, continues throughout the video, and sits top right. A separate "Recorded On" overlay applied in Axon Evidence is a static timestamp marking recording start, which can differ from the watermark when pre-event buffer video is present (the watermark shows earlier times). — [Axon Recorded On overlay](https://www.axon.com/help/axon-evidence/software/axon-evidence/evidence/review-evidence/recorded-on-overlay.htm)
- Axon Body Mini: "Date/time watermark can be embedded on video". — [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf)
- Getac BC-04: "Supports Date/Time/Officer ID stamp overlay on video footage". — [Getac BC-04 sheet](https://www.getac.com/content/dam/getac/all-sites-img/Getac_BC-04_Product_US_250116.pdf)
- Motorola VB400: "watermarked evidential outputs" with checksums (export-side watermarking). — [VB400 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/vb400-datasheet-na.pdf)
- Force Science (2014): built-in timestamps are coarse ("typically minute by minute") for perception-reaction analysis. Older observation; current Axon watermarks update per frame. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/); [Axon Recorded On overlay](https://www.axon.com/help/axon-evidence/software/axon-evidence/evidence/review-evidence/recorded-on-overlay.htm)

### Inferences
- **Generic layout for an invented brand:** top-right, two lines of small white monospace or condensed sans text with a thin dark outline or semi-transparent black box, ~2–2.5% of frame height per line.
  - Line 1: ISO-style date-time, e.g. `2026-11-08 T21:47:03 -0700` (or a trailing `Z` when UTC).
  - Line 2: `<BRAND> <MODEL>  <SERIAL>`, e.g. `VIGIL BODY 5  X9K4-0021783`.
  - Optional `MUTED` appended when audio is muted.
  - The seconds tick each second; the text is burned in, so it is compressed and blurred along with the image.
- The exact public look of Axon footage (format like `YYYY-MM-DD T HH:MM:SS ±offset`, then `AXON BODY n` plus serial, white text top right) matches my recollection of released footage, but no primary document confirming font, colour or exact string format was found. Treat as unverified.
- Optional "evidence playback" layer (released-footage look): static "Recorded On" stamp, redaction blur boxes, letterboxed agency title cards. These come from release editing, not the camera.

### Gaps
- No primary source for font, size, colour, background box or exact timestamp string format for Axon or Motorola watermarks. Motorola's on-camera overlay content was not documented in sources found.

---

## 6. Audio: pre-event silence, mic placement, sound character

### Takeaway
Audio comes from 2–4 small MEMS mics on the camera face, so the officer's own voice dominates (close, boomy), others sound distant and roomy, and wind, clothing rub, radio chatter and handling knocks are constant. **Pre-event buffer video is silent by default on Axon** (configurable), so released clips commonly start with ~30 s of silent video before audio cuts in.

### Cited Findings
- V700: "1 forward and 1 side pointing MEMS microphones to reduce wind noise". — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf). V300/V700 have two mics with foam baffles to block wind noise; V300 audio is AAC; V300 has no mute, V700 does. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- VB400: dual microphone; audio policy configurable to record "All footage", "All footage except footage captured during pre-record", or "No footage". — [VB400 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/vb400-datasheet-na.pdf)
- i-PRO BWC4000: four mics with noise cancelling; Kustom Argus: AI noise cancellation. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Axon AB4 has separate on/off settings for Record Audio, Pre-Event Buffer Audio and Audio in Video Recall; users can mute (push-and-hold or static). — [Axon AB4 settings](https://www.axon.com/help/axon-body-4/cameras-and-sensors/body/settings.htm). By default the camera does not capture audio in the pre-event buffer (admin can enable). — [Axon AB4 operation](https://www.axon.com/help/axon-body-4/cameras-and-sensors/body/operation.htm) (via search excerpt)
- Real case (Aug 2026, Anchorage): the police chief said the shooting footage had no audio because it fell within Axon's pre-event buffer. — [Alaska's News Source](https://www.alaskasnewssource.com/2026/08/15/police-chief-no-audio-recorded-body-cam-footage-officer-involved-shooting/)
- NYPD policy describes a 60-second "video only" pre-event buffer. — [NYPD BWC policy 2026](https://www.nyc.gov/assets/nypd/downloads/pdf/public_information/post-final/body-worn-cameras-nypd-Impact-and-use-policy_2.4.26_final.pdf) (via search excerpt)
- General wearable-mic behaviour: mics covered by clothing sound muffled; mics near the clip pick up rustle; wind is a common cause of unusable audio, and digital wind filters can degrade speech. — [Insta360 audio guide](https://www.insta360.com/blog/how-to-fix-audio-clipping-muffled-sound.html) (consumer source, via search excerpt)
- Getac integrates with in-car video so in-car and body audio can be played together, replacing a separate wireless mic. — [Getac BC-04 sheet](https://www.getac.com/content/dam/getac/all-sites-img/Getac_BC-04_Product_US_250116.pdf)

### Inferences (sound design defaults)
- Officer voice: close-mic proximity boom, sometimes clipped on shouts. Other speakers: −10 to −20 dB, roomy, thinner.
- Constant layers: polyester or nylon uniform rub on every arm move; duty-belt creak and keys; footsteps as body thumps; radio squelch and dispatch from a shoulder mic close by.
- Wind: low-frequency buffeting that ducks speech outdoors; aggressive noise suppression with "watery" artefacts.
- Running: rhythmic thumps and breath.
- Handling: loud knocks when the camera is touched or the officer goes prone.
- Codec: AAC, likely mono or near-mono, mid bitrate (not sourced). Mild low-pass, compressed dynamics, AGC pumping (noise floor rises in quiet moments).

### Gaps
- No audio sample rate, bitrate or channel count found for any police model.
- No law-enforcement-specific study of clothing-rub/wind artefacts was found; the guidance above comes from consumer sources plus inference.

---

## 7. Pre-event buffering behaviour and its visual signature

### Takeaway
Cameras constantly loop-record ("buffering", Axon front LED blinking green) and, on activation (button, holster draw, light bar, etc.), prepend the last N seconds (Axon default 30 s, range 0–120 s; others up to 10 min or full-shift "record after the fact"). **Signature: footage opens mid-action with silent video, then audio abruptly starts at the activation moment;** the burned-in time starts earlier than the "recording started" metadata.

### Cited Findings
- Axon pre-event buffer: default 30 s, configurable 0–120 s, video-only by default. Starting from sleep mode loses the buffer. — [Axon AB4 operation](https://www.axon.com/help/axon-body-4/cameras-and-sensors/body/operation.htm) (via search excerpt). Pre-event buffer "configurable up to 120 sec". — [AB4 card](https://cdn.mediavalet.com/usva/axon/lRL_NrK760OIbgl2z9W-bA/ixJhWEJZgU2E2WMqwDxsOw/Original/Axon%20Body%204%20Product%20Card%20Enterprise%20EN_GB.pdf). Axon Body Mini: 0–120 s in increments. — [Axon Body Mini specs](https://cdn.mediavalet.com/usva/axon/ZcSXZCI2DUiwgseIubG-5w/Ea0M4hsKZUeH3BIw-3PhjA/Original/Axon%20Body%20Mini%20Specs%20-%2018%20May%202026%2C%20EN_US.pdf)
- AB4 "Video Recall": an 18-hour recording buffer recallable later. Front lights "blink green during pre-event buffering, red when recording". — [Axon AB4 settings](https://www.axon.com/help/axon-body-4/cameras-and-sensors/body/settings.htm). DHS lists AB4 buffer as "30 sec–18 hrs". — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- Other buffers (DHS): Axon Body 3 30–120 s; V700 0–600 s or continuous; V300 0–120 s or continuous; VB400 120 s or continuous; Getac BC-03 10–120 s; i-PRO 0–180 s; Safe Fleet 0–199 s; WOLFCOM Halo 30 s–30 min. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf). Getac BC-04 max 2 min. — [Getac BC-04 sheet](https://www.getac.com/content/dam/getac/all-sites-img/Getac_BC-04_Product_US_250116.pdf)
- Motorola "Record-After-the-Fact": continuous caching (V700 up to 110 h at 480p; VB400 up to 19.5 h) recoverable even if never triggered. — [V700 datasheet](https://www.motorolasolutions.com/content/dam/msi/docs/products/body-worn-cameras/v700_datasheet.pdf); [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)
- London Metropolitan Police extended its buffer from 30 s to 60 s (report ~2019). — [Police Professional](https://policeprofessional.com/news/mps-doubles-pre-event-buffering-on-body-worn-video-units/). NYPD: 60 s video-only. — [NYPD BWC policy 2026](https://www.nyc.gov/assets/nypd/downloads/pdf/public_information/post-final/body-worn-cameras-nypd-Impact-and-use-policy_2.4.26_final.pdf) (via search excerpt)
- With a pre-event buffer the watermark time can be earlier than the "Recorded On" overlay. — [Axon Recorded On overlay](https://www.axon.com/help/axon-evidence/software/axon-evidence/evidence/review-evidence/recorded-on-overlay.htm)
- Automatic triggers include light bar/siren, vehicle speed, acceleration and g-force, door opening, unholstering, long-gun rack release, proximity to another recording camera, officer-down (prone), CAD and geofence. — [DHS SAVER](https://www.dhs.gov/sites/default/files/2024-02/24_02_29_st_bodyworncamerasmsr_1.pdf)

### Inferences (game mode behaviour)
- Implement a ring buffer (default 30 s). On "activation" (player presses record, draws weapon, or exits car with lights on), output starts 30 s back with audio muted (or a faint hiss), then hard-cuts to full audio at the activation frame. A small on-device "beep" or haptic sound marks the start in the recorded audio (the cameras have tones/haptics per Axon and Motorola specs; that the beep is audible in the recording is assumption).
- Possible extra signature: the buffer segment at reduced frame rate or quality (hinted by the Axon Mini "5fps/30fps" line). Optional and unverified; keep off by default.
- Watermark runs continuously across the join; there is no visual discontinuity other than audio onset (and a possible keyframe/quality jump at the splice).

### Gaps
- No primary documentation found on whether buffer video is encoded at lower frame rate or bitrate than active recording for Axon or Motorola.
- No source confirming that activation beeps or haptics are audible in recorded audio.
