# Bodycam footage of firearm handling, and the biomechanics of chest/head camera motion

Scope: what chest- and head-mounted bodycam footage of people handling guns looks like (gun placement in frame, occlusion, draw/recoil timing), and measured trunk/head motion during gait, for driving a bodycam-style first-person camera in a game. Values marked **(estimate)** are my own derivations or practitioner rules of thumb, not measured results.

Research note: web access was partly limited. Several primary PDFs (the Force Science/BJA PDF, PeerJ, the Thorstensson 1984 full text) were blocked or unreadable, so some numbers come from abstracts or secondary citations. Each case is flagged.

---

## 1. How guns and arms appear in frame from chest vs head cameras, by stance

### Takeaway
A chest camera sits below and behind the gun. In any extended two-handed stance (isosceles, Weaver), the arms and gun fill the lower-centre of the frame and often block the target. Footage from a chest camera "may not record much more than your extended arms and hands." Head and glasses cameras (Axon Flex style) sit near the eyes, see the target far more often, and follow head turns. Torso cameras lag head turns, and shoulder cameras are the worst: about 12% full target visibility in one live-fire study.

### Cited Findings
- Force Science Institute (Lewinski): with a chest-mounted camera, firing a gun or Taser may capture mostly the officer's extended arms and hands. Blading the stance (turning the torso side-on, as in Weaver or a rifle stance) can also block the view. The camera's view depends on its location and angle, and parts of the officer's own body, "from your nose to your hands," can block the picture. — [Police1, 10 limitations of body cams](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/); original Force Science document hosted by BJA: [force-science-body-cameras.pdf](https://bja.ojp.gov/sites/bja/files/media/document/force-science-body-cameras.pdf)
- A body camera records a broad scene but cannot show where in it the officer was looking. Lenses can compress distances or make objects look closer than they are. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)
- Suss & Petushek (2021, *Criminologie* 54(1):97-133): 3 officers ran 31 live-fire drills with handgun, patrol rifle and shotgun, varying start position, stance, grip and movement. Cameras were on both sides of a hat, both sides of glasses, both shoulders, the chest, and the firearm. Share of frames with the target fully visible, across all phases: head (hat/glasses) and chest about 80%, gun-mounted about 68%, shoulder about 12%. Pre-firing phase: all head mounts about 70%, all other mounts 14-41%. — [Michigan Tech Digital Commons abstract](https://digitalcommons.mtu.edu/michigantech-p/14889)
- Preliminary report of the same research (2018): in a turning drill the head moves first, so head cameras captured more of the target. Torso mounts are "less stable" and can be shifted or blocked when officers raise their arms. A shoulder, epaulette or collar mount can be tilted by the shoulder's movement until the camera points at the ground. Axon magnetic mounts let officers move the camera between glasses, shoulder, cap and chest, but can pop off in ground fights. — [AIP Inside Science](https://www.aip.org/inside-science/the-science-behind-where-police-should-place-their-body-cameras)
- Murray, Lewinski et al. (2024, *Police Practice and Research*): 44 active-duty officers wore eye-tracking glasses plus a chest-mounted GoPro standing in for a bodycam during a use-of-force scenario. Officers looked at about 80% of critical events, but the chest camera captured only 66.2%. For key events it captured under 48%, and the suspect's shooting about 46% of the time. The authors attribute the gap to the camera sitting lower than the eyes and being less mobile than the head. — [Tactical Science summary](https://tacticalscience.substack.com/p/the-eyes-have-it); [Taylor & Francis DOI 10.1080/15614263.2024.2328664](https://informahealthcare.com/doi/full/10.1080/15614263.2024.2328664); [Montclair record](https://researchwith.montclair.edu/en/publications/the-eyes-have-it-functional-field-of-view-differences-between-vis/)
- Field of view: manufacturers claim 120-170° for bodycams, but one test measured 72-114°. — cited in the search summary for the [Murray et al. 2024 record](https://informahealthcare.com/doi/full/10.1080/15614263.2024.2328664) (secondary; the original test was not identified)
- No head-mounted camera can see everything the eye can. The best bodycams top out around a 180° FOV. — [Officer.com, "A Matter of Perspective"](https://www.officer.com/on-the-street/body-cameras/article/21251789/body-cameras-a-matter-of-perspective) (practitioner commentary)

### Inferences (for animation; all estimates)
- **Chest camera, pistol isosceles (arms fully extended, gun at eye height):** the camera is about 25-35 cm below the eyes, so the line from lens to gun points upward. The hands and gun sit in the upper-middle to centre of frame, with both forearms rising from the lower left and right corners to form a "V". The arms and gun plausibly take up about 20-35% of the frame area in a wide (about 110-140° horizontal) lens **(estimate)**. The sights almost never line up in shot, because the lens is not on the sight line. You see the slide's underside or rear and the hands, not a sight picture.
- **Chest camera, Weaver or bladed stance:** the torso turns about 30-45° toward the strong side. The camera now points off-axis, roughly toward the support-side shoulder of the target, and the support arm crosses the frame diagonally **(estimate)**. This is the "torso rotation hides the threat" effect Force Science mentions with blading.
- **Compressed or close-contact ready (gun at the sternum or ribcage):** the gun sits just above or beside the lens, often only the top of the slide or the hands in the bottom 10-20% of frame, or out of frame entirely. A camera on the sternum can be partly blocked by the hands and wrists **(estimate)**.
- **Low ready (muzzle about 45° down):** the gun and hands sit in the bottom centre, muzzle pointing at the lower frame edge, arms in the lower third **(estimate)**.
- **High ready (gun at chin or chest height, muzzle up or forward):** the hands take up the lower-centre of frame and can block the middle of the image **(estimate)**.
- **Rifle shouldered:** the stock is on the strong-side shoulder pocket, close to a chest-centre camera. The handguard and support arm run diagonally from the lower strong-side corner toward the centre. The optic is visible from below or behind, but never through it **(estimate)**. On a shoulder camera, raising the rifle can push the camera or turn it away (consistent with the AIP and Suss findings).
- **Rifle low ready:** the muzzle points at the lower frame edge, the handguard runs diagonally across the bottom third, and the support hand is visible **(estimate)**.
- **Head or glasses camera (Axon Flex, POV kits):** the lens sits about 3-10 cm beside the eye, so the view is close to a classic FPS: the gun appears just below centre, and an iron-sight or red-dot picture is partly visible, though offset by the parallax between the side-mounted lens and the eye **(estimate)**. The camera turns with the head, so turns arrive about 100-200 ms earlier than on a chest camera (see section 4).

### Gaps
- No measured "percentage of frame filled by arms/gun" exists in the sources found. The Suss studies measured target visibility, not how much of the frame the gun fills.
- No published per-stance (isosceles/Weaver/compressed) occlusion figures. The Suss 2021 abstract does not break results down by stance.
- Axon Body 4 POV specifics (lens FOV, mount offsets) were not found in primary sources.

---

## 2. What happens in frame during a draw, reload, corner clear, moving with a gun, and recoil; draw and recovery timings

### Takeaway
Measured draw-to-first-shot from a holster after a stimulus is about 1.5-1.9 s for average officers (1.78 ± 0.33 s, n = 148). From a ready position it is 0.64 s (low ready, unaimed) to 0.83 s (high ready, aimed). Pistol muzzle rise and return show in footage as a quick upward flick plus a few small bounces as the slide closes. I found no peer-reviewed split-time or recovery-time values.

### Cited Findings
- Arizona AZPOST study, 148 certified officers, 3 yards, single cold attempt, shot timer: mean draw-to-first-shot 1.777 s (SD ±0.329). Open-top or no-retention holsters (n = 6): 1.493 ± 0.126 s. Glock + Safariland 6280 (Level 3 retention) was slowest at 1.87 s. Tuller's 1986 baseline assumed 1.5 s. — [VirTra summary of study](https://www.virtra.com/time-analysis-of-a-certified-peace-officers-blog/)
- Force Science-based coverage: average officers take about 1.5-1.7 s to draw from a Level I holster and fire one round in response to a stimulus. — [Police1 / Officer.com coverage via search](https://www.officer.com/article/10248725/fractions-of-a-second); [Police Magazine, "Rethinking reaction time"](https://www.policemag.com/articles/rethinking-reaction-time)
- Force Science (Lewinski, *Law Enforcement Executive Forum*, reported by Police1 2015), 68 LAPD volunteers, time to first shot from a ready position: low ready 0.64 s (unaimed), high ready 0.83 s (aimed), high guard 1.13 s, "bootleg" 1.32 s. Shotgun (n = 9): high ready 0.84 s, low ready 0.99 s, port 1.28 s. Finger resting on the slide adds about 0.08 s to reach the trigger and over 0.10 s to fire. — [Police1, finger placement and ready position](https://www.police1.com/officer-safety/articles/how-much-do-finger-placement-and-ready-position-matter-aVMZMe7Xh9wqJB2d)
- With the hand already on the gun, Force Science measured an average of 0.23 s from first movement to shot for a "combat tuck" (compressed, fired from the hip or chest) and 0.26 s for an extended draw (fastest 0.09 s). — search summary of [Police1 coverage](https://www.police1.com/police-trainers/articles/charging-the-bullet-a-scientific-evaluation-of-our-tactics-1RJNIRNXTdgikVpr) (secondary; not opened in full)
- Officers can trail the on-screen action by "half a second or more" because of reaction time, and footage does not show this. Bodycams record at a higher frame rate than typical CCTV, but a brief muzzle flash can still fall between frames. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)
- Recoil: "rise" time adds to "return" time, so less muzzle rise means faster recovery. — [American Rifleman, "Three Rs: Rise, Return & Realignment"](https://www.americanrifleman.org/content/the-three-rs-of-performance-shooting-rise-return-realignment/)
- High-speed footage shows the pistol's muzzle bouncing up and down a few times as the slide closes, and a locked-breech design spreads recoil over a longer impulse. — [Lucky Gunner Lounge, recoil](https://www.luckygunner.com/lounge/recoil-lets-talk-about-feelings/amp/)
- An informal test found a load with about 25% more recoil made split times about 21.5% slower (small, uncontrolled). — [Gun Digest, Understanding Handgun Recoil](https://gundigest.com/more/how-to/firearm-training/handgun-recoil)
- Mantis X defines "recovery time" (muzzle back on target) separately from "muzzle rise" (peak angle). — [Mantis X recoilmeter drill](https://mantisx.com/blogs/news/the-hidden-power-of-the-recoilmeter-drill-and-why-you-should-be-using-it)

### Inferences (for animation; estimates)
- **Draw on a chest camera:** for most of the draw the gun is below or beside the lens and out of frame. The strong-side elbow may cross the lower corner. The gun appears in the lower-centre only at the "press out" (last ~0.2-0.3 s), then rises to the upper-centre at full extension. Phases to animate: grip (0-0.3 s) → clear holster (0.3-0.6) → rotate and press out (0.6-1.1) → first shot (about 1.2-1.8 s from stimulus for an average officer) **(estimate, timed against the measured totals above)**.
- **Recoil on a chest camera:** the camera is on the torso, not the gun, so the image barely moves. What moves is the gun or hands in frame: a sharp upward flick of the muzzle by a few degrees, then return with one or two small bounces over about 0.15-0.3 s. Practitioner split times for trained shooters are often quoted at 0.2-0.3 s, but I found no measured source **(estimate)**. The torso takes a small backward or upward pulse that a game could show as a sub-degree camera pitch kick **(estimate)**. On a head camera the whole image kicks up slightly with the head.
- **Muzzle flash:** at 30 fps (a common bodycam rate) a flash lasting a few milliseconds is captured in only some frames, so random 0-1 frame flashes are realistic **(estimate, consistent with Force Science's frame-gap point)**.
- **Reload on a chest camera:** the gun comes back toward the chest into a "workspace" just below eye line, which on a chest camera puts it in the upper-centre or close to the lens. The magazine and hands fill a large part of the frame, sometimes blurred because they sit inside the lens's minimum focus distance **(estimate)**.
- **Corner clearing ("slicing the pie"):** the head looks first and the torso follows. A chest camera therefore shows the corner after the eyes have seen it (see section 4 on head-trunk separation during turns).

### Gaps
- No peer-reviewed measurement of pistol muzzle-rise angle (degrees) or recovery time in duty shooters was found.
- No measured reload times for officers (practitioner-quoted emergency reloads of about 2-3 s were not sourced).
- No published frame-by-frame description of bodycam footage of draws or reloads was found that avoids graphic content; the descriptions above are geometric inferences.

---

## 3. Chest camera vs eye: documented discrepancies

### Takeaway
The best-evidenced discrepancies are: (1) the chest camera sits below the eyes and does not move with the head, so it misses what the officer was looking at (66% vs 80% of critical events captured); (2) the arms and gun block the lens when shooting; (3) blading or torso rotation points the camera away from the threat; (4) the 2D wide lens distorts distance; (5) the camera can see better or worse than the eye in low light.

### Cited Findings
- Chest camera captured 66.2% of critical events vs about 80% seen by the officer. Key events were captured under 48% of the time, and the suspect's shooting 46% vs about 80% seen. — [Tactical Science summary of Murray et al. 2024](https://tacticalscience.substack.com/p/the-eyes-have-it)
- Arms and hands block the lens when firing, and blading the stance can block the view. — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)
- In low light, the camera may record more than the officer could see, and it struggles with lighting transitions, which "may briefly blank out images altogether." — [Police1 / Force Science](https://www.police1.com/police-products/body-cameras/articles/10-limitations-of-body-cams-you-need-to-know-for-your-protection-Y0Lhpm3vlPTsJ9OZ/)
- In turning tasks the head moves first, so a head camera captures the target sooner than a torso camera. — [AIP Inside Science](https://www.aip.org/inside-science/the-science-behind-where-police-should-place-their-body-cameras)
- During standing 180° turns, peak head-thorax separation was 13.2 ± 11.0° (Vicon) and peak head yaw velocity 194 ± 77 °/s, with step frequency during turning about 2.2-2.3 Hz (n = 12, forehead and mid-thorax IMUs). — [PMC7249140 (Sensors 2020)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7249140)

### Inferences
- In-game, a chest camera should lead with nothing and lag the player's look direction. When the player turns, rotate the "eye" (player aim) first, then let the chest camera follow with about 10-20° of maximum separation and a lag of roughly 80-200 ms **(estimate, based on the 13° mean ± 11° peak separation and about 200 °/s head yaw)**.
- The gun can point at a target that is outside the chest camera's frame (high over the lens at full extension, or off-axis in a bladed stance), which reproduces the "camera didn't see the threat" quality of real footage **(estimate)**.

### Gaps
- No NIJ technical standard or court analysis with numeric camera-vs-eye offsets was retrieved. Court cases were not reviewed because of the tool budget.

---

## 4. Gait biomechanics: trunk and head oscillation, step frequency, angles, head stabilisation, weapon-aimed walking

### Takeaway
Walking: the trunk rises and falls twice per stride (once per step) at about 1.4-2.5 Hz step frequency (about 2 Hz typical), with roughly 2.5-5 cm peak-to-peak vertical motion. Lateral sway happens once per stride (about 1 Hz) and is smaller. Trunk pitch varies by about 4-6° and transverse (yaw) rotation by a few degrees. The head is actively stabilised in pitch, counter-rotating against vertical bob. Running: lumbar or trunk vertical oscillation is about 6-10 cm (decreasing with speed), and lateral oscillation about 2.4-5.3 cm (increasing with speed). Head pitch amplitude and velocity are much larger when running.

### Cited Findings
**Vertical and lateral translation**
- Thorstensson et al. 1984 (*Acta Physiol Scand* 121:9-22), 10 males, treadmill, walking 1.0-2.5 m/s and running 2.0-6.0 m/s: the trunk shows two vertical oscillations per stride with mean net amplitudes of about 2.5-9.5 cm across conditions (walking at the low end, running at the high end), plus forward-backward oscillation of about 0.5-3 cm. Lateral oscillation occurs once per stride; its amplitude figures could not be read. — [Scilit record](https://scilit.com/publications/93f4779da5b491214bcc0725ab32a741) (abstract via search snippet; full text not accessed)
- Lee & Farley 1998 (*J Exp Biol*), near the walk-run transition speed: over the first half of stance, the centre of mass rose about 3.1 cm in walking and fell about 7.3 cm in running. — [search summary; JEB](https://cob.silverchair.com/jeb/article-pdf/208/12/2333/1545202/2333.pdf) (secondary)
- Gard, Miff & Kuo 2004 (*Hum Mov Sci* 22:597-610): the sacral-marker method overestimates vertical COM excursion at faster walking speeds, so a single torso point is a fair approximation only at slow or self-selected speeds. No values were extracted. — [Record](https://katalog.lib.cas.cz/KNAV/EdsRecord/edselp,S016794570300085X)
- Treadmill running with an IMU at L4-L5 (n = 18, *Frontiers in Sports and Active Living* 2024), peak-to-peak displacement: vertical 10.2 ± 1.8 cm at 9 km/h, 8.5 ± 1.4 cm at 15 km/h, 6.1 ± 1.5 cm at 21 km/h. Mediolateral 2.4 ± 0.8 cm at 9 km/h, 4.5 ± 1.4 cm at 15 km/h, 5.2 ± 1.5 cm at 21 km/h. The paper's discussion quotes slightly different numbers (VT 10.2→6.8 cm; ML 2.1→5.3 cm), an internal inconsistency. — [Frontiers 10.3389/fspor.2024.1357353](https://www.frontiersin.org/articles/10.3389/fspor.2024.1357353/full)
- Coaching sources put recreational running vertical oscillation at 6-9 cm, and an unverified blog treadmill test reports 9.8 cm at 160 steps/min falling to 6.8 cm at 192 steps/min (10 km/h). Low reliability. — [RunnersConnect](https://runnersconnect.net/improve-your-vertical-oscillation-for-better-running-performance/); [ctyeh.com](https://ctyeh.com/articles/14631?lang=en)

**Step frequency**
- Hirasaki et al. 1999 (*Exp Brain Res* 127:117-130), treadmill 0.6-2.2 m/s: the dominant frequency of head translation and rotation rose from 1.4 Hz at 0.6 m/s to 2.5 Hz at 2.2 m/s. Between 0.8 and 1.8 m/s people mostly lengthen their stride, so the frequency stays near 2.0 Hz. Trunk pitch stays roughly constant as speed increases, while head translation grows. — [Springer record](https://link.springer.com/doi/10.1007/s002210050781) (abstract)
- Over 10+ h of daily-life IMU recording (10 adults, 34,455 steps), the dominant head vertical frequency averaged 1.86 ± 0.23 Hz. Head and trunk vertical RMS acceleration peaked at about 0.3 g. Head vertical acceleration and head pitch were phase-shifted by about −50°. — [Hausamann et al. 2019, Frontiers in Human Neuroscience](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2019.00179/full)
- Running cadence typically 166-178+ steps/min (about 2.8-3.0 Hz). — [ACSM, distance running form](https://acsm.org/distance-running-form-tips/)

**Angles and angular velocity**
- Pozzo et al. 1990, human walking: head pitch displacement 9 ± 3°, peak head pitch velocity 30 ± 8 °/s, head vertical velocity 25-35 cm/s. Running: head pitch 14 ± 4°, 72 ± 20 °/s, head vertical velocity 70-150 cm/s. — as tabulated in [Dunbar et al. 2008, PMC2768006](https://pmc.ncbi.nlm.nih.gov/articles/PMC2768006) (secondary table; units for Pozzo's displacement as given there)
- Cromwell & Wellmon 2001, walking: head pitch 8 ± 2°, trunk pitch 6 ± 2°, neck pitch 14 ± 4°. Cromwell et al. 2004: trunk pitch 4 ± 1°, max head pitch velocity 9 ± 3 °/s. — [PMC2768006 table](https://pmc.ncbi.nlm.nih.gov/articles/PMC2768006)
- Across studies, reported head pitch peak amplitude during locomotion ranges from 1.5° to 7.5°, with peak velocities of 28-149 °/s. Head sagittal displacement is kept "within a few degrees." — [search summary of reviews; Frontiers / JEB results](https://cob.silverchair.com/jeb/article-split/211/24/3889/18018/Stabilization-and-mobility-of-the-head-neck-and)
- Note the conflict: Pozzo's 9° walking head pitch (as tabulated by Dunbar) vs "1.5-7.5°" across studies. The difference is likely peak-to-peak vs peak amplitude, or the measurement frame.
- Thoracic trunk range of motion in walking is reported at about 2.4-2.6° in one cited study (plane unconfirmed). Torso angular ranges in walking are "small." — [PeerJ 9329](https://peerj.com/articles/9329); [preprint 202504.1189](https://www.preprints.org/manuscript/202504.1189) (secondary)
- Transverse (yaw) plane: thorax and pelvis rotate nearly in phase at slow speeds (relative phase about −20°) and move toward anti-phase as speed rises (about −140° at 1.5 m/s). Minimum transverse ranges of motion of 2.9° (C7-T8), 5.1° (C7-sacrum) and 2.8° (T8-sacrum) were reported in a thoracic-pain cohort study. — [BMC Musculoskeletal Disorders 14:345](https://bmcmusculoskeletdisord.biomedcentral.com/articles/10.1186/1471-2474-14-345); [RUG, thorax-lumbar-pelvis at three velocities](https://research.rug.nl/en/publications/interaction-between-thorax-lumbar-and-pelvis-movements-in-the-tra/)
- Head stabilisation mechanism: compensatory head pitch counteracts vertical translation, driven by the angular vestibulocollic reflex at low speeds and the linear one at higher speeds. — [Hirasaki 1999](https://link.springer.com/doi/10.1007/s002210050781)

**Walking with a weapon at aim ("tactical"/Groucho gait)**
- Tactical athletes "shooting on the move": tactical gait differs from normal gait. Each 1% more of the gait cycle spent in double-limb support was associated with a 0.13 cm increase in dynamic mean radial error. — [search summary of "Estimating marksmanship performance during walking while maintaining weapon aim"](https://bohrium.dp.tech/paper/arxiv/36722162) (abstract only; page fetch failed)
- Neugebauer & Talarico (2017) compared normal walking with walking while holding weapon aim (spatiotemporal and lower-body kinematics). Results not retrieved. — [Record](https://katalog.lib.cas.cz/KNAV/EdsRecord/edsair,edsair.doi...........16e7c38578093fd5ae13aab684a0eb17)

### Inferences (suggested animation parameters; estimates)
- **Chest camera, normal walk (about 1.3-1.5 m/s):** vertical bob of 3-4 cm peak-to-peak at the step frequency (about 1.8-2.0 Hz). Lateral sway of 2-4 cm peak-to-peak at half that frequency (stride, about 0.9-1.0 Hz). Trunk yaw of ±2-4° at stride frequency. Roll of ±1-2° at stride frequency. Pitch of ±1-3° at step frequency. Unlike a head camera, a chest camera gets no vestibular counter-rotation, so its image looks shakier than a head camera's. **(Estimate: magnitudes drawn from the Thorstensson, Lee & Farley and Cromwell values; lateral and roll values are not directly sourced.)**
- **Chest camera, run (about 3-4 m/s, about 2.7-3.0 Hz cadence):** vertical bob of 7-10 cm, lateral sway of 3-5 cm, plus sharp vertical impact transients at foot strike (trunk RMS acceleration well above walking's 0.3 g). Larger pitch and yaw jitter **(estimate, from the Frontiers 2024 values at 9-15 km/h)**.
- **Head or glasses camera:** similar translation, but the head pitch counter-rotates (about −50° phase to vertical acceleration). The image stays nearly level, and the horizon drifts by only a few degrees **(estimate)**.
- **Tactical or Groucho walk (knees bent, heel-to-toe, gun at aim):** reduce vertical bob to about 1-2 cm and lower the step frequency (about 1.2-1.6 Hz) with longer double support. Upper-body yaw is held to the target, so most camera motion is low-amplitude vertical and lateral translation **(estimate; no measured values found)**.
- **Turning:** the eyes and head lead the chest by up to about 13° on average (peak values much larger), at head yaw rates of about 200 °/s. The chest camera should follow with a lag.

### Gaps
- No measured sternum- or chest-specific peak-to-peak vertical or lateral displacement for walking was found (only trunk or lumbar values and COM estimates).
- Trunk roll amplitude in walking was not found in a primary source.
- No measured kinematics of the Groucho or tactical walk (vertical bob, cadence) were found; the Neugebauer & Talarico results were not accessible.
- Effect of load (body armour, duty belt about 9-14 kg) on trunk oscillation was not researched.

---

## 5. Camera shake spectra from body-worn or egocentric cameras

### Takeaway
I found no study that publishes a frequency or amplitude spectrum of bodycam image shake. The best proxies are head and trunk IMU spectra during gait (dominant about 1.4-2.5 Hz walking, about 2.5-3 Hz running, with harmonics), and egocentric-vision work showing that optical flow tracks head motion only moderately (r ≈ 0.62).

### Cited Findings
- The dominant head vertical frequency in daily life is about 1.86 ± 0.23 Hz, with head and trunk vertical acceleration strongly correlated across 1-2.6 Hz. — [Hausamann et al. 2019](https://www.frontiersin.org/journals/human-neuroscience/articles/10.3389/fnhum.2019.00179/full)
- The dominant frequency of head translation and rotation is 1.4-2.5 Hz over 0.6-2.2 m/s. — [Hirasaki 1999](https://link.springer.com/doi/10.1007/s002210050781)
- Optical flow statistics from head-mounted camera video correlate with head motion (Pearson r = 0.62 in one example), but flow also includes scene motion. — [Estimating Head Motion from Egocentric Vision, ICMI 2018](https://vision.soic.indiana.edu/papers/headmotion2018icmi.pdf)
- Datasets with synchronised egocentric video and full-body kinematics exist (walking, side-stepping, obstacles), along with an egocentric dataset recorded with head, chest and waist cameras on 10 participants. — [Scientific Data 2023, non-laboratory gait + egocentric vision](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9837188/); [Egocentric Height Estimation, arXiv 1610.02714](https://arxiv.org/pdf/1610.02714)

### Inferences (estimates)
- Build chest-camera shake as a sum of components: a fundamental at step frequency (vertical, pitch), a component at half step frequency (lateral, roll, yaw), a 2nd harmonic at about 20-30% amplitude, and short decaying impulses at each foot strike (about 5-15 Hz content, stronger when running). Add low-frequency (<0.5 Hz) drift from breathing and posture **(estimate)**.
- Camera-specific artefacts that sell the look: rolling-shutter wobble on high-frequency impacts, motion blur at 30 fps, and electronic image stabilisation that smooths sub-2 Hz motion but lets impacts through **(estimate; not sourced)**.

### Gaps
- No published bodycam (Axon or Motorola) shake spectrum or EIS characterisation was found.
- CVPR/ICCV video stabilisation papers (for example hyperlapse work) were not reached within the tool budget, so wearable-camera motion statistics from that literature remain unverified.
