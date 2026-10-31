---
name: natural-form-art-study
description: Research and refine a natural-form asset against botanical, geological, zoological, or other reliable references using a measured, silhouette-first art study and repeatable visual reviews.
---

# Natural Form Art Study

Use this workflow when a natural asset must read convincingly from reference, especially when a procedural generator needs reusable controls instead of a one-off species model.

## 1. Register the evidence

- Record each source image, specimen page, paper, and current candidate with its URL or path, date, view/crop, dimensions or scale, and the question it can answer.
- Prefer primary scientific work, herbarium or botanical-garden records, university extensions, and direct domain references. Use production talks and tool manuals for workflow evidence, not biological claims.
- Seek complementary views and life stages. A perspective photo can support silhouette and attachment observations; do not infer metric proportions from an unscaled oblique view.
- Keep **observed**, **inferred**, and **unknown** traits separate, with confidence. Preserve conflicting evidence instead of averaging it into false certainty.

## 2. Write a morphology contract

Describe the whole-organism habit before the details: its support, base, main axes, branching order, repeated-organ attachment, age stages, and characteristic posture. Then describe diagnostic organs by silhouette, profile, attachment, curvature, margins, openings, surface, and material.

Turn each important observation into a viewable invariant or bounded target. Distinguish identity features from optional variation. In plants, distinguish inner perforations from openings that cut through the leaf margin; distinguish lobes from serrations; and distinguish healthy posture from stress, damage, or an artistic presentation choice.

## 3. Study and build from large to small

1. Capture the unedited candidate and a neutral/clay silhouette at a consistent camera and scale.
2. Match whole-form habit and negative space before refining organ detail.
3. Represent axes as paths or branching structure with explicit organ attachment points; keep leaf, flower, fruit, and root geometry independently parameterized.
4. Add placement rules and positional gradients along parent axes for size, angle, droop, maturity, and spacing where the biology or art target supports them.
5. Refine organ outline and cross-section before surface detail. Inspect front, side, rear, and top views so a flattering camera cannot hide flatness, alignment, broken attachment, or silhouette errors.
6. Add material and fine variation last, then review again in the intended game, animation, or product context.

This is a production order for diagnosis, not a claim that every natural form shares one growth mechanism.

## 4. Use math and procedural variation carefully

- Use branching grammars, phyllotaxis, fractals, space filling, or noise only when they explain or art-direct an observed relation. No single pattern is a universal “natural” setting.
- Use bounded, seeded, trait-specific variation. A noise control should change meaningful features such as organ size, orientation, path curvature, node spacing, surface undulation, or opening size while preserving the morphology contract.
- Keep positional gradients distinct from per-organ randomness: a gradient changes a feature predictably along an axis; randomness perturbs individual instances around that trend.
- Separate visually different structures into separate controls or geometry. For leaves, outline, lobe depth, margin teeth, internal holes, edge splits, twist, fold, curl, and gravity sag are different traits.
- Do not claim that a procedural recipe simulates DNA, development, or physical growth unless those mechanisms are actually modeled and validated.

## 5. Iterate with bounded reviews

For each pass, record the highest-impact mismatch, its likely cause, one source-visible change, and the view that will prove it. Keep seeds, camera, scale, lighting, and crop fixed while comparing candidates. Change structure before detail; if a pass exposes a structural error, return to the morphology contract instead of adding more noise.

Review the changed view and at least one complementary view after each structural edit. Score or describe semantic read, silhouette, attachment, posture, organ geometry, variation, and integration separately from technical validity. Treat a compiling or deterministic asset as technically checked, not visually accepted.

Stop only after two consecutive bounded reviews find no actionable source-visible mismatch, or state the remaining mismatch, uncertainty, and next evidence needed. Do not call a species study converged when the available reference views cannot resolve its defining traits.

### Grade the result and rotate coverage

- Give every reviewed candidate an overall visual grade from 0–10 and short component grades for the traits that matter to its morphology (for example silhouette, attachment, posture/physics, organ shape, density/variation, and reference match). Do not let deterministic output, passing tests, or a polished material raise the visual grade by itself.
- Pair the grade with evidence: strongest match, highest-impact mismatch, likely cause, one concrete next change, and the view that can confirm or reject the change. Keep technical validation separate from visual acceptance.
- In a reusable shape tool, maintain a coverage matrix of exposed form families and distinct habits/architectures already represented. Prioritize empty and single-example families before adding many near-duplicates to a mature family. A useful initial breadth target is several clearly different examples per family; the project or user may set a different target.
- Allow a few bounded iterations when each pass tests a meaningful hypothesis. If roughly three consecutive reviews do not improve the graded defect, record the remaining issue and rotate to a different asset or family. Return later only with new evidence, a better hypothesis, or a reusable capability to test.

## 6. Deliver the study

Provide a compact evidence register, morphology contract, candidate images, iteration notes, control-to-trait mapping, technical checks, visual review, and unresolved questions. Keep the study recipe reproducible by storing its seed and parameter values. Use the project's existing report or gallery generator when one exists; do not create a duplicate review surface.

## Method sources

- [Kew: Botanical art](https://www.kew.org/read-and-watch/what-is-botanic-art) — working from measured specimens and diagnostic features.
- [Prusinkiewicz et al.: Positional information in plant modeling](https://www.algorithmicbotany.org/papers/positional.sig2001.html) — posture, gradual feature changes, and positional functions along plant axes.
- [SpeedTree: Modeling approach](https://docs9.speedtree.com/modeler/doku.php?id=kcmodelingapproach) and [generation properties](https://docs9.speedtree.com/modeler/doku.php?id=generation_properties) — procedural hierarchy, curves, placement, and per-property variation.
- [Runions et al.: Leaf venation modeling](https://algorithmicbotany.org/papers/venation.sig2005.html) — connected structure for leaf surface networks.
- [GDC: Vegetation of Horizon Zero Dawn](https://gdcvault.com/play/1025530/Between-Tech-and-Art-The) — production relationship between art direction and vegetation technology.
